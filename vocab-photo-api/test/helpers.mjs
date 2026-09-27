// Shared helpers for the Worker tests. `scripts/test.mjs` (`npm test`) starts
// `wrangler dev` and passes its address, secrets file and local state dir in
// the environment.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

if (!process.env.VOCAB_API_BASE_URL) {
  throw new Error("VOCAB_API_BASE_URL is not set — run the tests with `npm test`, not `node --test` directly");
}

/** Where the local Worker answers, e.g. `http://127.0.0.1:54321`. */
export const baseUrl = process.env.VOCAB_API_BASE_URL;

function readDevVars(path) {
  const vars = {};
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m) vars[m[1]] = m[2].replace(/^(["'])(.*)\1$/, "$2");
  }
  return vars;
}

const devVars = readDevVars(process.env.VOCAB_API_DEV_VARS);

let clientCount = 0;

/**
 * Headers the app sends on secret-gated routes. Each call comes from its own
 * client address (miniflare keeps a `cf-connecting-ip` the request brings), so
 * the per-IP limit of 20 a minute never trips over a whole suite's requests; a
 * test of the limit itself passes its own `cf-connecting-ip` in `extra`.
 */
export function appHeaders(extra = {}) {
  clientCount += 1;
  const ip = `10.${(clientCount >> 16) & 255}.${(clientCount >> 8) & 255}.${clientCount & 255}`;
  return { "x-app-secret": devVars.APP_SHARED_SECRET, "cf-connecting-ip": ip, ...extra };
}

/**
 * Publishes a session the way the app does (POST /sessions) and returns the
 * parsed answer, `{ id, url, expiresAt, editToken }`. Throws on a non-2xx answer.
 */
export async function publish(body = { entries: [{ word: "apple", translation: "яблуко" }] }) {
  const res = await publishRaw(body);
  if (!res.ok) throw new Error(`publish answered ${res.status}: ${await res.text()}`);
  return res.json();
}

/** POST /sessions with `body` and the app's secret; returns the raw response. */
export function publishRaw(body) {
  return send("/sessions", {
    method: "POST",
    headers: appHeaders({ "content-type": "application/json" }),
    body: JSON.stringify(body),
  });
}

/** Uploads `bytes` as a declared photo, the way the app will (T18); returns the raw response. */
export function uploadSource(sessionId, sourceId, bytes, mediaType = "image/png") {
  return send(`/sessions/${sessionId}/sources/${sourceId}`, {
    method: "POST",
    headers: appHeaders({ "content-type": mediaType }),
    body: bytes,
  });
}

/**
 * Runs a wrangler command against the local state `wrangler dev` is serving
 * from, e.g. to seed a KV document or move a session's expiry. Throws with
 * wrangler's output when it fails.
 */
function wranglerLocal(args) {
  const res = spawnSync("npx", ["wrangler", ...args, "--local", "--persist-to", process.env.VOCAB_API_STATE_DIR], {
    cwd: fileURLToPath(new URL("..", import.meta.url)),
    encoding: "utf8",
    env: { ...process.env, CI: "1" },
  });
  if (res.status !== 0) throw new Error(`wrangler ${args.join(" ")} failed:\n${res.stdout}${res.stderr}`);
  return res.stdout;
}

/** Runs SQL on the local D1 database and returns the rows of the last statement. */
export function d1(sql) {
  const out = JSON.parse(wranglerLocal(["d1", "execute", "DB", "--json", "--command", sql]));
  return out.at(-1).results;
}

/** Writes a value into the local `SESSIONS` KV namespace. */
export function kvPut(key, value) {
  wranglerLocal(["kv", "key", "put", key, value, "--binding", "SESSIONS"]);
}

/** Deletes a key from the local `SESSIONS` KV namespace. */
export function kvDelete(key) {
  wranglerLocal(["kv", "key", "delete", key, "--binding", "SESSIONS"]);
}

/**
 * Sends a request to the local Worker, retried once when the connection is
 * reset before any answer. `fetch` reuses keep-alive sockets, and after a test
 * pauses for a wrangler subprocess (`d1`, `kvPut`) its next request now and
 * then goes out on a socket the local server has just dropped -- the request
 * never reaches the Worker, so sending it again is safe (and every write the
 * tests send is one a retry cannot harm: a publish makes a fresh link, a
 * repeated photo upload is a no-op).
 */
async function send(path, init) {
  try {
    return await fetch(`${baseUrl}${path}`, init);
  } catch (err) {
    if (err?.cause?.code !== "ECONNRESET") throw err;
    return fetch(`${baseUrl}${path}`, init);
  }
}

/** GET `path` from the local Worker. */
export function get(path) {
  return send(path);
}
