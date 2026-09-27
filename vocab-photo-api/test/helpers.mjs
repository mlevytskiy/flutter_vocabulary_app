// Shared helpers for the Worker tests. `scripts/test.mjs` (`npm test`) starts
// `wrangler dev` and passes its address and secrets file in the environment.
import { readFileSync } from "node:fs";

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

/** Headers the app sends on secret-gated routes. */
export function appHeaders(extra = {}) {
  return { "x-app-secret": devVars.APP_SHARED_SECRET, ...extra };
}

/**
 * Publishes a session the way the app does (POST /sessions) and returns the
 * parsed answer, `{ id, url, expiresAt }`. Throws on a non-2xx answer.
 */
export async function publish(body = { entries: [{ word: "apple", translation: "яблуко" }] }) {
  const res = await fetch(`${baseUrl}/sessions`, {
    method: "POST",
    headers: appHeaders({ "content-type": "application/json" }),
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`publish answered ${res.status}: ${await res.text()}`);
  return res.json();
}
