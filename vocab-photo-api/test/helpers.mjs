// Shared helpers for the Worker tests. `scripts/test.mjs` (`npm test`) starts
// `wrangler dev` and passes its address, secrets file and local state dir in
// the environment.
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
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

let partnerCount = 0;

/**
 * A partner's JSON request from the shared page (public, no secret). Like
 * `appHeaders`, each call comes from its own address unless `ip` is given, so
 * only a test of the page write limit shares one budget. Returns
 * `{ status, body }` with the body parsed.
 */
export async function pagePost(path, body, ip) {
  partnerCount += 1;
  const address = ip ?? `172.16.${(partnerCount >> 8) & 255}.${partnerCount & 255}`;
  const res = await send(path, {
    method: "POST",
    headers: { "content-type": "application/json", "cf-connecting-ip": address },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

/** SQL string literal for `d1()`. */
export const sql = (value) => `'${String(value).replace(/'/g, "''")}'`;

/** The rows of a session as D1 holds them, tombstones included, in table order. */
export function storedRows(sessionId) {
  return d1(
    `SELECT id, position, source_id, word, word_rev, translation, translation_rev, definition, definition_rev,
       deleted_at_rev FROM rows WHERE session_id = ${sql(sessionId)} ORDER BY position`
  );
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

let localDb;

/**
 * The SQLite file `wrangler dev` keeps the local D1 database in, opened once
 * per test file. Local D1 runs in WAL mode, so this connection and the
 * Worker's see each other's committed writes -- the same thing
 * `wrangler d1 execute --local` relies on, minus its ~3 s start per call.
 * `null` when the file is not where miniflare keeps it today.
 */
function openLocalDb() {
  if (localDb !== undefined) return localDb;
  const dir = join(process.env.VOCAB_API_STATE_DIR, "v3", "d1", "miniflare-D1DatabaseObject");
  const file = existsSync(dir) && readdirSync(dir).find((name) => name.endsWith(".sqlite") && name !== "metadata.sqlite");
  localDb = file ? new DatabaseSync(join(dir, file)) : null;
  localDb?.exec("PRAGMA busy_timeout = 5000");
  return localDb;
}

/**
 * Runs SQL on the local D1 database and returns the rows of the last statement.
 * Falls back to `wrangler d1 execute` (slow) when the file cannot be found.
 */
export function d1(sql) {
  const db = openLocalDb();
  if (!db) return JSON.parse(wranglerLocal(["d1", "execute", "DB", "--json", "--command", sql])).at(-1).results;
  // `prepare` takes the first statement only; `sourceSQL` says where it ended.
  const stmt = db.prepare(sql);
  const rows = stmt.all().map((row) => ({ ...row }));
  const rest = sql.slice(stmt.sourceSQL.length);
  return rest.trim().replace(/^;+$/, "") ? d1(rest) : rows;
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
 * pauses for a wrangler subprocess (`kvPut`, or `d1` on its fallback) its next
 * request now and then goes out on a socket the local server has just dropped -- the request
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
