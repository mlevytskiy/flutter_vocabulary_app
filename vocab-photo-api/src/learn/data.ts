// POST /learn/data -- the exercise data service (learn-kit, H-02, S-14 – S-17, S-19, S-24).
// Per word, in the sense of its translation: read the LEARN_DATA cache, ask the fixed AI once for
// the misses only, check each answer against its kind's rule, cache what passed (30 days) and answer
// per rowId in request order. A broken answer is `null` and not cached, so it is asked again.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { DEFINITION_CACHE_TTL_SECONDS } from "../define.ts";
import { jsonResponse } from "../http.ts";
import { logEvent } from "../log.ts";
import type { RouteContext, RouteDefinition } from "../routing";
import { GROUPING_MODEL } from "../story/models.ts";
import { writeText } from "../story/providers/text.ts";
import { matchPlaces } from "../story/word-check.ts";
import { takeLearnData } from "./allowance.ts";
import { dataPrompt } from "./prompts.ts";

export const LEARN_DATA_KINDS = ["synonym", "definition", "clues", "sentence", "pattern", "translate"] as const;
export type LearnDataKind = (typeof LEARN_DATA_KINDS)[number];

export interface LearnDataWord {
  rowId: string;
  word: string;
  translation: string;
}

/** The largest word group (S-14). */
export const MAX_DATA_WORDS = 19;
const MAX_ID_LENGTH = 100;
const MAX_WORD_LENGTH = 100;
const MAX_TRANSLATION_LENGTH = 200;
/** One AI call: output limit and time limit (S-17); the app gives up at 30 s. */
const DATA_MAX_OUTPUT_TOKENS = 3000;
const DATA_TIMEOUT_MS = 25_000;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** `{kind, words: [{rowId, word, translation}]}`, or the reason it is not one (AC-23). */
export function parseDataRequest(body: unknown): { kind: LearnDataKind; words: LearnDataWord[]; error?: undefined } | { error: string } {
  if (!isRecord(body)) return { error: "Body must be a JSON object" };
  if (!LEARN_DATA_KINDS.includes(body.kind as LearnDataKind)) return { error: `kind must be one of ${LEARN_DATA_KINDS.join(", ")}` };
  if (!Array.isArray(body.words) || body.words.length === 0) return { error: "words must be a non-empty list" };
  if (body.words.length > MAX_DATA_WORDS) return { error: `at most ${MAX_DATA_WORDS} words` };
  const words: LearnDataWord[] = [];
  const seen = new Set<string>();
  for (const item of body.words) {
    if (!isRecord(item)) return { error: "each word must be {rowId, word, translation}" };
    const { rowId, word, translation = "" } = item;
    if (typeof rowId !== "string" || rowId === "" || rowId.length > MAX_ID_LENGTH) return { error: `each rowId must be 1-${MAX_ID_LENGTH} characters` };
    if (seen.has(rowId)) return { error: "a rowId is used twice" };
    seen.add(rowId);
    if (typeof word !== "string" || word.trim() === "" || word.length > MAX_WORD_LENGTH) return { error: `each word must be 1-${MAX_WORD_LENGTH} characters` };
    if (typeof translation !== "string" || translation.length > MAX_TRANSLATION_LENGTH) {
      return { error: `a translation may hold at most ${MAX_TRANSLATION_LENGTH} characters` };
    }
    words.push({ rowId, word, translation });
  }
  return { kind: body.kind as LearnDataKind, words };
}

/** S-16: `learn:v1:<kind>:<sha256 of lower(trim(word)) | lower(trim(translation))>`. Bump v1 when a prompt or shape changes. */
export async function cacheKey(kind: LearnDataKind, word: string, translation: string): Promise<string> {
  const text = `${word.trim().toLowerCase()}|${translation.trim().toLowerCase()}`;
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  const hex = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `learn:v1:${kind}:${hex}`;
}

// ---- each kind's rule (S-15, AC-25) ----

const str = (value: unknown, max: number): string | undefined =>
  typeof value === "string" && value.trim() !== "" && value.length <= max ? value : undefined;
const norm = (text: string) => text.trim().toLowerCase().replace(/\s+/g, " ");
const wordCount = (text: string) => text.trim().split(/\s+/).length;
const holdsOnce = (text: string, word: string) => matchPlaces(text, word).length === 1;

const SLOTS = new Set(["noun", "verb", "adjective", "sentence", "verb in Past Simple"]);

function sentenceOf(value: unknown, word: string): string | undefined {
  const sentence = str(value, 120);
  return sentence && wordCount(sentence) <= 15 && holdsOnce(sentence, word) ? sentence : undefined;
}

function patternOf(value: unknown, word: string): string | undefined {
  const pattern = str(value, 60);
  if (!pattern || matchPlaces(pattern, word).length > 0) return undefined;
  const slots = [...pattern.matchAll(/\[([^\[\]]*)\]/g)].map((m) => m[1]);
  if (slots.length === 0 || !slots.every((s) => SLOTS.has(s))) return undefined;
  // No stray bracket outside a slot.
  return /[\[\]]/.test(pattern.replace(/\[[^\[\]]*\]/g, "")) ? undefined : pattern;
}

/** The value with only its kind's fields when it keeps the rule, else undefined. */
export function checkValue(kind: LearnDataKind, value: unknown, w: LearnDataWord): Record<string, unknown> | undefined {
  if (!isRecord(value)) return undefined;
  switch (kind) {
    case "synonym": {
      const synonym = str(value.synonym, 40);
      return synonym && norm(synonym) !== norm(w.word) ? { synonym } : undefined;
    }
    case "definition": {
      const definition = str(value.definition, 160);
      return definition ? { definition } : undefined;
    }
    case "clues": {
      const clues = value.clues;
      if (!Array.isArray(clues) || clues.length !== 3) return undefined;
      const checked = clues.map((c) => str(c, 120));
      return checked.every((c) => c !== undefined) ? { clues: checked } : undefined;
    }
    case "sentence": {
      const sentence = sentenceOf(value.sentence, w.word);
      return sentence ? { sentence } : undefined;
    }
    case "pattern": {
      const sentence = sentenceOf(value.sentence, w.word);
      const pattern = patternOf(value.pattern, w.word);
      const usage = str(value.usage, 60);
      return sentence && pattern && usage ? { sentence, pattern, usage } : undefined;
    }
    case "translate": {
      const source = str(value.source, 200);
      const cue = str(value.cue, 200);
      const model = str(value.model, 200);
      if (!source || !cue || !model) return undefined;
      if (matchPlaces(source, w.word).length > 0 || !source.includes(cue) || !holdsOnce(model, w.word)) return undefined;
      return { source, cue, model };
    }
  }
}

/** The reply's items (a fenced block is allowed), or undefined when it is not `{items: [...]}`. */
export function parseDataReply(reply: string): unknown[] | undefined {
  const trimmed = reply.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  try {
    const parsed: unknown = JSON.parse(fenced ? fenced[1] : trimmed);
    return isRecord(parsed) && Array.isArray(parsed.items) ? parsed.items : undefined;
  } catch {
    return undefined;
  }
}

// ---- the route ----

type Value = Record<string, unknown> | null;

async function readCached(kv: KVNamespace, key: string): Promise<{ v: Value } | undefined> {
  try {
    const raw = await kv.get(key);
    if (raw === null) return undefined;
    const parsed: unknown = JSON.parse(raw);
    return isRecord(parsed) && "v" in parsed && (parsed.v === null || isRecord(parsed.v)) ? { v: parsed.v as Value } : undefined;
  } catch {
    return undefined;
  }
}

const badRequest = (error: string) => jsonResponse({ error, code: "bad_request" }, 400);

async function handleLearnData({ request, env }: RouteContext): Promise<Response> {
  const started = Date.now();
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return badRequest("Body must be JSON");
  }
  const parsed = parseDataRequest(body);
  if (parsed.error !== undefined) return badRequest(parsed.error);
  const { kind, words } = parsed;
  const kv = env.LEARN_DATA;
  if (!kv) return jsonResponse({ error: "Exercise data is not available", code: "no_storage" }, 503);

  const keys = await Promise.all(words.map((w) => cacheKey(kind, w.word, w.translation)));
  const cached = await Promise.all(keys.map((key) => readCached(kv, key)));
  const values = new Map<string, Value>();
  const misses: LearnDataWord[] = [];
  words.forEach((w, i) => {
    const hit = cached[i];
    if (hit) values.set(w.rowId, hit.v);
    else misses.push(w);
  });
  const log = (outcome: string) =>
    logEvent("learn data", {
      kind, words: words.length, hits: words.length - misses.length, misses: misses.length, outcome, ms: Date.now() - started,
      // Words only for misses, as /define logs the words it looks up (S-24).
      ...(misses.length > 0 ? { missed: misses.map((w) => w.word).join(",") } : {}),
    });

  if (misses.length > 0) {
    // One unit per AI call, taken before it and never given back (S-18, AC-24, AC-27).
    if (!(await takeLearnData(env))) {
      log("day_limit");
      return jsonResponse({ error: "Today's exercise limit is reached", code: "day_limit" }, 429);
    }
    const { system, user } = dataPrompt(kind, misses);
    const result = await writeText(env, {
      model: GROUPING_MODEL,
      system,
      user,
      maxOutputTokens: DATA_MAX_OUTPUT_TOKENS,
      timeoutMs: Number(env.LEARN_AI_TIMEOUT_MS) || DATA_TIMEOUT_MS,
    });
    const items = result.failed === undefined ? parseDataReply(result.text) : undefined;
    if (!items) {
      log(result.failed ?? "unreadable");
      return jsonResponse({ error: "Could not make the exercise data", code: "learn_failed" }, 502);
    }
    const byRow = new Map<string, Record<string, unknown>>();
    for (const item of items) {
      if (isRecord(item) && typeof item.rowId === "string" && !byRow.has(item.rowId)) byRow.set(item.rowId, item);
    }
    const writes: Promise<void>[] = [];
    for (const w of misses) {
      const item = byRow.get(w.rowId);
      const value = item === undefined ? undefined : item.none === true ? null : checkValue(kind, item, w);
      values.set(w.rowId, value ?? null);
      // A real "none" is cached as null; a broken or missing answer is not cached (S-16).
      if (value !== undefined) {
        const key = keys[words.indexOf(w)];
        writes.push(kv.put(key, JSON.stringify({ v: value }), { expirationTtl: DEFINITION_CACHE_TTL_SECONDS }));
      }
    }
    await Promise.all(writes);
  }
  log("ok");
  return jsonResponse({ kind, results: words.map((w) => ({ rowId: w.rowId, value: values.get(w.rowId) ?? null })) });
}

export const learnDataRoute: RouteDefinition = { method: "POST", pattern: /^\/learn\/data$/, public: false, handler: handleLearnData };
