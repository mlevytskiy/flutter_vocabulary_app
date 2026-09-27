// `npm test`: starts `wrangler dev` on a free port with fresh local bindings
// (D1/KV/R2/rate limiters simulated under a throwaway --persist-to dir), waits
// until it answers, runs `node --test` over test/**/*.test.mjs against it, then
// stops it. No package beyond wrangler itself (sad §10).
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

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
}
process.on("SIGINT", () => {
  stopWorker();
  process.exit(130);
});

let code;
try {
  await waitUntilUp(baseUrl, worker, 60_000);
  code = await run(process.execPath, ["--test", "test/**/*.test.mjs"], {
    cwd: root,
    env: { ...process.env, VOCAB_API_BASE_URL: baseUrl, VOCAB_API_DEV_VARS: join(root, devVars) },
  });
} catch (err) {
  console.error(String(err));
  console.error("--- wrangler dev output ---\n" + log);
  code = 1;
} finally {
  stopWorker();
}
process.exit(code);
