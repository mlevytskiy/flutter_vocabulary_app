import type { Env } from "./env";
import { jsonResponse } from "./http";
import type { RouteContext, RouteDefinition } from "./routing";

// Dictionary lookups for the app's definition field (definition-mode, ADR-0002).
// The Merriam-Webster key lives only here, as the MW_API_KEY secret; the app
// asks this route and gets exactly one of three outcomes back, never the
// dictionary's raw format:
//   { outcome: "senses", word, senses: string[] }          200
//   { outcome: "not_found", word, suggestions: string[] }  200
//   { outcome: "unavailable", error }                      503

const MW_URL = "https://www.dictionaryapi.com/api/v3/references/collegiate/json/";
const MW_TIMEOUT_MS = 4_000;
const MAX_WORD_CHARS = 100;
const MAX_SUGGESTIONS = 5;
/** Same lifetime as published sessions (sad §7). */
export const DEFINITION_CACHE_TTL_SECONDS = 30 * 24 * 60 * 60;

type LookupResult =
  | { outcome: "senses"; word: string; senses: string[] }
  | { outcome: "not_found"; word: string; suggestions: string[] }
  | { outcome: "unavailable"; error: string };

async function handleDefine({ request, env }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON with a `word` string" }, 400);
  }
  const raw = (body as { word?: unknown } | null)?.word;
  if (typeof raw !== "string" || raw.trim() === "") {
    return jsonResponse({ error: "Body must be JSON with a `word` string" }, 400);
  }
  const word = raw.trim();
  if (word.length > MAX_WORD_CHARS) {
    return jsonResponse({ error: `A word may hold at most ${MAX_WORD_CHARS} characters` }, 400);
  }

  const started = Date.now();
  const cacheKey = `def:${word.toLowerCase()}`;
  const cached = await readCache(env, cacheKey);
  if (cached) {
    log("cache hit", word, started);
    return jsonResponse({ outcome: "senses", word, senses: cached });
  }

  const result = await lookUp(env, word);
  log(result.outcome === "not_found" ? "not found" : result.outcome === "senses" ? "found" : "unavailable", word, started);
  if (result.outcome === "senses") {
    // Only successful answers are cached, so an outage can never stick.
    await env.DEFINITIONS.put(cacheKey, JSON.stringify(result.senses), {
      expirationTtl: DEFINITION_CACHE_TTL_SECONDS,
    });
  }
  return jsonResponse(result, result.outcome === "unavailable" ? 503 : 200);
}

async function readCache(env: Env, key: string): Promise<string[] | null> {
  try {
    const value = await env.DEFINITIONS.get(key);
    if (value === null) return null;
    const senses: unknown = JSON.parse(value);
    return Array.isArray(senses) && senses.every((s) => typeof s === "string") && senses.length > 0
      ? (senses as string[])
      : null;
  } catch {
    return null;
  }
}

async function lookUp(env: Env, word: string): Promise<LookupResult> {
  if (!env.MW_API_KEY) return { outcome: "unavailable", error: "Dictionary is not configured" };
  let response: Response;
  try {
    response = await fetch(`${MW_URL}${encodeURIComponent(word)}?key=${encodeURIComponent(env.MW_API_KEY)}`, {
      signal: AbortSignal.timeout(MW_TIMEOUT_MS),
    });
  } catch {
    return { outcome: "unavailable", error: "Dictionary did not answer in time" };
  }
  if (!response.ok) return { outcome: "unavailable", error: `Dictionary answered ${response.status}` };

  let entries: unknown;
  try {
    entries = await response.json();
  } catch {
    // Merriam-Webster answers an invalid or exhausted key with a plain-text page.
    return { outcome: "unavailable", error: "Dictionary answered with an unexpected format" };
  }
  return parseEntries(word, entries);
}

/**
 * An unknown word comes back as an array of spelling-suggestion strings; a
 * known one as entries. Compounds and run-ons (`direct` → `direct current`)
 * are dropped when the headword itself has entries.
 */
export function parseEntries(word: string, entries: unknown): LookupResult {
  if (!Array.isArray(entries)) return { outcome: "unavailable", error: "Dictionary answered with an unexpected format" };
  if (entries.length === 0 || typeof entries[0] === "string") {
    const suggestions = entries.filter((e): e is string => typeof e === "string").slice(0, MAX_SUGGESTIONS);
    return { outcome: "not_found", word, suggestions };
  }
  type Entry = { meta?: { id?: unknown }; shortdef?: unknown };
  const all = entries.filter((e): e is Entry => typeof e === "object" && e !== null);
  const headword = word.toLowerCase();
  const own = all.filter((e) => typeof e.meta?.id === "string" && e.meta.id.split(":")[0].toLowerCase() === headword);
  const senses = (own.length ? own : all)
    .flatMap((e) => (Array.isArray(e.shortdef) ? e.shortdef : []))
    .filter((s): s is string => typeof s === "string" && s.trim() !== "")
    .map((s) => s.trim());
  return senses.length ? { outcome: "senses", word, senses } : { outcome: "not_found", word, suggestions: [] };
}

function log(outcome: string, word: string, started: number): void {
  console.log(`define ${outcome} "${word}" ${Date.now() - started}ms`);
}

export const defineRoutes: RouteDefinition[] = [
  { method: "POST", pattern: /^\/define$/, public: false, handler: handleDefine },
];
