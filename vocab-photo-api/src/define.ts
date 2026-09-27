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
  // v2: senses are "definition: …\nexample: …" strings (see formatSense);
  // answers cached in the older shortdef format are ignored.
  const cacheKey = `def:v2:${word.toLowerCase()}`;
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
 * are dropped when the headword itself has entries, and so are abbreviation
 * entries (`Test` → "Testament").
 *
 * Each sense becomes one string for the app's Definition field:
 *   definition: <the explanation, synonyms removed>
 *   example: <how the word is used>        (only when the dictionary has one)
 * read from the full `def` data, which carries the example sentences that
 * `shortdef` leaves out.
 */
export function parseEntries(word: string, entries: unknown): LookupResult {
  if (!Array.isArray(entries)) return { outcome: "unavailable", error: "Dictionary answered with an unexpected format" };
  if (entries.length === 0 || typeof entries[0] === "string") {
    const suggestions = entries.filter((e): e is string => typeof e === "string").slice(0, MAX_SUGGESTIONS);
    return { outcome: "not_found", word, suggestions };
  }
  const all = entries.filter((e): e is Entry => typeof e === "object" && e !== null && e.fl !== "abbreviation");
  const headword = word.toLowerCase();
  const own = all.filter((e) => typeof e.meta?.id === "string" && e.meta.id.split(":")[0].toLowerCase() === headword);
  const senses: string[] = [];
  for (const entry of own.length ? own : all) {
    const fromDef = sensesOf(entry);
    // Entries without usable `def` data fall back to their shortdef lines.
    const found = fromDef.length ? fromDef : fallbackShortdef(entry);
    for (const sense of found) if (!senses.includes(sense)) senses.push(sense);
  }
  const capped = senses.slice(0, MAX_SENSES);
  return capped.length ? { outcome: "senses", word, senses: capped } : { outcome: "not_found", word, suggestions: [] };
}

const MAX_SENSES = 10;

type Entry = { meta?: { id?: unknown }; fl?: unknown; def?: unknown; shortdef?: unknown };
type Sense = { dt?: unknown };

/** Walks `def[].sseq`: each item is a `sense`, a `bs` (binding sense) or a `pseq` of those. */
function sensesOf(entry: Entry): string[] {
  const out: string[] = [];
  const visit = (item: unknown): void => {
    if (!Array.isArray(item) || typeof item[0] !== "string") return;
    const [kind, data] = item as [string, unknown];
    if (kind === "sense") add(data as Sense);
    else if (kind === "bs") add((data as { sense?: Sense })?.sense);
    else if (kind === "pseq" && Array.isArray(data)) data.forEach(visit);
  };
  const add = (sense: Sense | undefined): void => {
    const formatted = formatSense(sense);
    if (formatted) out.push(formatted);
  };
  const defs = Array.isArray(entry.def) ? entry.def : [];
  for (const d of defs) {
    const sseq = (d as { sseq?: unknown })?.sseq;
    if (!Array.isArray(sseq)) continue;
    for (const group of sseq) if (Array.isArray(group)) group.forEach(visit);
  }
  return out;
}

/**
 * "definition: …" plus "\nexample: …" when the sense has an example. Null for
 * senses with nothing left once synonyms are removed (`{bc}{sx|cupel||}`) and
 * for heading senses whose meaning is in their sub-senses ("…: such as").
 */
export function formatSense(sense: Sense | undefined): string | null {
  const dt = Array.isArray(sense?.dt) ? sense!.dt : [];
  let text = "";
  let example: string | null = null;
  const scan = (items: unknown[]): void => {
    for (const item of items) {
      if (!Array.isArray(item)) continue;
      const [kind, data] = item as [string, unknown];
      if (kind === "text" && typeof data === "string" && !text) text = cleanMarkup(data);
      else if (kind === "vis" && Array.isArray(data) && example === null) {
        const first = data.find((v) => typeof (v as { t?: unknown })?.t === "string") as { t: string } | undefined;
        if (first) example = cleanMarkup(first.t);
      } else if (kind === "uns" && Array.isArray(data)) {
        // Usage notes nest their own text/vis items; only their examples are kept.
        for (const note of data) if (Array.isArray(note)) scanExamplesOnly(note);
      }
    }
  };
  const scanExamplesOnly = (items: unknown[]): void => {
    for (const item of items) {
      if (!Array.isArray(item) || item[0] !== "vis" || !Array.isArray(item[1]) || example !== null) continue;
      const first = item[1].find((v: unknown) => typeof (v as { t?: unknown })?.t === "string") as { t: string } | undefined;
      if (first) example = cleanMarkup(first.t);
    }
  };
  scan(dt);
  text = text.replace(/[\s:;,]+$/, "").trim();
  if (!text || /such as$/i.test(text)) return null;
  return example ? `definition: ${text}\nexample: ${example}` : `definition: ${text}`;
}

/**
 * Merriam-Webster's inline markup → plain text. `{bc}` is the bold colon in
 * front of a definition and `{sx|word||}` a synonym cross-reference: both are
 * removed, so "{bc}moving slowly {bc}{sx|sluggish||}" becomes "moving slowly".
 * Link tokens keep their word; formatting tokens keep their content.
 */
export function cleanMarkup(raw: string): string {
  return raw
    .replace(/\{bc\}\s*\{sx\|[^}]*\}(\s*,?\s*\{sx\|[^}]*\})*/g, "")
    .replace(/\{sx\|[^}]*\}/g, "")
    .replace(/\{bc\}/g, " ")
    .replace(/\{(?:a_link|d_link|i_link|et_link|mat|dxt)\|([^|}]*)[^}]*\}/g, "$1")
    .replace(/\{ldquo\}/g, "\u201c")
    .replace(/\{rdquo\}/g, "\u201d")
    .replace(/\{[^}]*\}/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function fallbackShortdef(entry: Entry): string[] {
  const lines = Array.isArray(entry.shortdef) ? entry.shortdef : [];
  return lines
    .filter((l): l is string => typeof l === "string")
    .map((l) => l.split(" : ")[0].replace(/\s*\u2014.*$/, "").trim())
    .filter((l) => l && !/such as$/i.test(l))
    .map((l) => `definition: ${l}`);
}

function log(outcome: string, word: string, started: number): void {
  console.log(`define ${outcome} "${word}" ${Date.now() - started}ms`);
}

export const defineRoutes: RouteDefinition[] = [
  { method: "POST", pattern: /^\/define$/, public: false, handler: handleDefine },
];
