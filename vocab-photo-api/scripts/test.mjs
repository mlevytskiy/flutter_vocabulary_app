// Starts `wrangler dev` on a free port with fresh local bindings (D1/KV/R2/rate
// limiters simulated under a throwaway --persist-to dir, with the D1 migrations
// applied), waits until it answers, runs `node --test` against it, then stops it.
// Which files run (docs/testing.md):
//   npm test                          the smoke test only (test/smoke.test.mjs)
//   npm test -- test/a.test.mjs ...   the smoke test plus the files named
//   npm run test:full                 every test/**/*.test.mjs (full regression)
// No package beyond wrangler itself (sad §10). The dictionary is a local stub (`test/mw-stub.mjs`), so no
// test spends the real Merriam-Webster quota. The AI behind subtitle imports is
// a local stub too (`test/anthropic-stub.mjs`), so no test spends Anthropic credit.
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { startMwStub } from "../test/mw-stub.mjs";
import { startAnthropicStub } from "../test/anthropic-stub.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

// The local secrets: `.dev.vars` when the developer has one, otherwise the
// committed example so a clean checkout still runs. The tests read the same file.
const devVars = existsSync(join(root, ".dev.vars")) ? ".dev.vars" : ".dev.vars.example";

function freePort() {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

async function waitUntilUp(baseUrl, worker, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (worker.exitCode !== null) throw new Error(`wrangler dev exited with code ${worker.exitCode}`);
    try {
      await fetch(`${baseUrl}/s/readiness-probe`);
      return;
    } catch {
      await new Promise((ok) => setTimeout(ok, 250));
    }
  }
  throw new Error(`wrangler dev did not answer within ${timeoutMs / 1000}s`);
}

function run(command, args, options) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: "inherit", ...options });
    child.on("exit", (code, signal) => resolve(code ?? (signal ? 1 : 0)));
  });
}

const port = await freePort();
const inspectorPort = await freePort();
const baseUrl = `http://127.0.0.1:${port}`;
const stateDir = mkdtempSync(join(tmpdir(), "vocab-photo-api-test-"));
const mwStub = await startMwStub();
const aiStub = await startAnthropicStub();

const migrate = spawnSync(
  "npx",
  ["wrangler", "d1", "migrations", "apply", "DB", "--local", "--persist-to", stateDir],
  { cwd: root, encoding: "utf8", env: { ...process.env, CI: "1" } },
);
if (migrate.status !== 0) {
  console.error("--- wrangler d1 migrations apply output ---\n" + migrate.stdout + migrate.stderr);
  rmSync(stateDir, { recursive: true, force: true });
  process.exit(1);
}

let log = "";
const worker = spawn(
  "npx",
  [
    "wrangler", "dev",
    "--ip", "127.0.0.1",
    "--port", String(port),
    "--inspector-port", String(inspectorPort),
    "--persist-to", stateDir,
    "--env-file", devVars,
    // After --env-file, so these win over a real key in .dev.vars.
    "--var", `MW_API_URL:${mwStub.url}`,
    "--var", "MW_API_KEY:test-key",
    "--var", `ANTHROPIC_API_URL:${aiStub.url}`,
    "--var", "ANTHROPIC_API_KEY:test-key",
    // The stub's slow reply (6 s) must outlast this, so a test can see the 225 s abort.
    "--var", "SUBTITLE_AI_TIMEOUT_MS:3000",
    // GET /__scheduled runs the cron handler (the daily clean-up).
    "--test-scheduled",
    "--show-interactive-dev-session=false",
    "--log-level", "warn",
  ],
  // Own process group, so stopping it also stops workerd underneath.
  { cwd: root, detached: true, stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, CI: "1" } },
);
worker.stdout.on("data", (chunk) => (log += chunk));
worker.stderr.on("data", (chunk) => (log += chunk));

function stopWorker() {
  if (worker.exitCode === null) {
    try {
      process.kill(-worker.pid, "SIGTERM");
    } catch {
      // Already gone.
    }
  }
  rmSync(stateDir, { recursive: true, force: true });
  mwStub.close();
  aiStub.close();
}
process.on("SIGINT", () => {
  stopWorker();
  process.exit(130);
});

let code;
try {
  await waitUntilUp(baseUrl, worker, 60_000);
  // One file at a time: the files share one `wrangler dev` and one local D1, and
  // several of them reset or count the same day totals.
  const args = process.argv.slice(2);
  const named = args.filter((arg) => arg !== "--full");
  const files = args.includes("--full") ? ["test/**/*.test.mjs"] : [...new Set(["test/smoke.test.mjs", ...named])];
  console.log(`# running ${args.includes("--full") ? "the full regression" : files.join(", ")}`);
  code = await run(process.execPath, ["--test", "--test-concurrency=1", ...files], {
    cwd: root,
    env: {
      ...process.env,
      // test/helpers.mjs reads the local D1 through node:sqlite.
      NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ""} --disable-warning=ExperimentalWarning`.trim(),
      VOCAB_API_BASE_URL: baseUrl,
      VOCAB_API_DEV_VARS: join(root, devVars),
      VOCAB_API_STATE_DIR: stateDir,
      VOCAB_API_MW_STUB_URL: mwStub.url,
      VOCAB_API_AI_STUB_URL: aiStub.url,
    },
  });
  if (code !== 0) console.error("--- wrangler dev output ---\n" + log);
} catch (err) {
  console.error(String(err));
  console.error("--- wrangler dev output ---\n" + log);
  code = 1;
} finally {
  stopWorker();
}
process.exit(code);
