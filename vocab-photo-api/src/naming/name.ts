// Collection naming (owner, 2026-10-18): once a collection has 5 words and nobody named it,
// the app asks for a short name for it. The Worker asks the AI (Sonnet 5.5 unless the app
// asks for another offered Anthropic text model) and cleans its answer; the app stores it.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { offeredModels } from "../story/models.ts";
import { writeText, type TextEnv } from "../story/providers/text.ts";

export const DEFAULT_NAMING_MODEL = "claude-sonnet-5-5";
/** The app's limit on a collection name, in code points (lib/core/models/collection_name.dart). */
export const MAX_NAME_LENGTH = 60;
export const MAX_NAMING_WORDS = 50;
const MAX_WORD_LENGTH = 200;
const NAMING_TIMEOUT_MS = 30_000;
const NAMING_MAX_OUTPUT_TOKENS = 1000;

export interface NamingWord {
  word: string;
  translation?: string;
}
export interface NamingRequest {
  words: NamingWord[];
  model: string;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isNamingModel = (id: string) =>
  offeredModels.some((m) => m.id === id && m.role === "text" && m.provider === "anthropic");

/** `{words: [{word, translation?}], model?}`, or the reason it is not one. */
export function parseNamingRequest(body: unknown): NamingRequest | { error: string; code?: string } {
  if (!isRecord(body) || !Array.isArray(body.words)) return { error: "words must be a list" };
  if (body.words.length === 0) return { error: "words must not be empty" };
  if (body.words.length > MAX_NAMING_WORDS) return { error: `at most ${MAX_NAMING_WORDS} words` };
  const words: NamingWord[] = [];
  for (const item of body.words) {
    const word = isRecord(item) && typeof item.word === "string" ? item.word.trim() : "";
    if (!word || word.length > MAX_WORD_LENGTH) return { error: "each word needs a word of at most 200 characters" };
    const t = isRecord(item) && typeof item.translation === "string" ? item.translation.trim().slice(0, MAX_WORD_LENGTH) : "";
    words.push(t ? { word, translation: t } : { word });
  }
  const model = body.model ?? DEFAULT_NAMING_MODEL;
  if (typeof model !== "string" || !isNamingModel(model)) return { error: "That AI is not offered", code: "not_offered" };
  return { words, model };
}

export function namingPrompt({ words }: NamingRequest): { system: string; user: string } {
  return {
    system: [
      "You name a learner's vocabulary collection after what its words have in common.",
      "The user message is JSON: \"words\", each an English \"word\" with an optional \"translation\".",
      "Give one short, plain English name of one to four words (at most 40 characters), in title case, such as \"Kitchen Tools\" or \"Travel and Airports\".",
      "Name the shared topic; when the words share none, name what they are best (\"Everyday Verbs\", \"Mixed Adjectives\").",
      "No quotes, no emoji, no full stop, no word \"vocabulary\".",
      "Reply with ONLY a strict JSON object, no prose and no code fences: {\"name\": \"<the name>\"}",
    ].join("\n"),
    user: JSON.stringify({ words }),
  };
}

/** The name in the AI's reply, made fit for the app: one line, no quotes or final stop, at most 60 code points. */
export function parseNamingReply(reply: string): string | undefined {
  const trimmed = reply.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  let raw: unknown;
  try {
    const parsed: unknown = JSON.parse(fenced ? fenced[1] : trimmed);
    raw = isRecord(parsed) ? parsed.name : undefined;
  } catch {
    return undefined;
  }
  if (typeof raw !== "string") return undefined;
  let name = raw.replace(/\s+/g, " ").trim().replace(/^["“”«»']+|["“”«»']+$/g, "").trim().replace(/\.$/, "").trim();
  const points = [...name];
  if (points.length > MAX_NAME_LENGTH) {
    name = points.slice(0, MAX_NAME_LENGTH).join("");
    const space = name.lastIndexOf(" ");
    if (space > 0) name = name.slice(0, space);
    name = name.trim();
  }
  return name === "" ? undefined : name;
}

export async function nameCollection(env: TextEnv, request: NamingRequest): Promise<string | undefined> {
  const { system, user } = namingPrompt(request);
  const result = await writeText(env, {
    model: request.model,
    system,
    user,
    timeoutMs: NAMING_TIMEOUT_MS,
    maxOutputTokens: NAMING_MAX_OUTPUT_TOKENS,
  });
  return result.failed === undefined ? parseNamingReply(result.text) : undefined;
}

// ---- the description, from 20 words on (owner, 2026-10-18) ----

/** The longest description kept, in code points (the app's MAX: lib/core/models/collection_name.dart). */
export const MAX_DESCRIPTION_LENGTH = 300;

export function describePrompt({ words }: NamingRequest): { system: string; user: string } {
  return {
    system: [
      "You describe a learner's vocabulary set for the learner's own notes.",
      "The user message is JSON: \"words\", each an English \"word\" with an optional \"translation\".",
      "Write one or two plain English sentences (at most 200 characters) saying what the words are about and where they would be useful, such as \"Words for cooking at home: tools, actions and what happens in the kitchen.\"",
      "Do not list the words one by one, do not address the learner, no emoji, no quotes.",
      "Reply with ONLY a strict JSON object, no prose and no code fences: {\"description\": \"<the description>\"}",
    ].join("\n"),
    user: JSON.stringify({ words }),
  };
}

/** The description in the AI's reply: one paragraph, no quotes, at most 300 code points cut at a word. */
export function parseDescriptionReply(reply: string): string | undefined {
  const trimmed = reply.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  let raw: unknown;
  try {
    const parsed: unknown = JSON.parse(fenced ? fenced[1] : trimmed);
    raw = isRecord(parsed) ? parsed.description : undefined;
  } catch {
    return undefined;
  }
  if (typeof raw !== "string") return undefined;
  let text = raw.replace(/\s+/g, " ").trim().replace(/^["“”«»]+|["“”«»]+$/g, "").trim();
  const points = [...text];
  if (points.length > MAX_DESCRIPTION_LENGTH) {
    text = points.slice(0, MAX_DESCRIPTION_LENGTH).join("");
    const space = text.lastIndexOf(" ");
    if (space > 0) text = text.slice(0, space);
    text = text.trim();
  }
  return text === "" ? undefined : text;
}

export async function describeCollection(env: TextEnv, request: NamingRequest): Promise<string | undefined> {
  const { system, user } = describePrompt(request);
  const result = await writeText(env, {
    model: request.model,
    system,
    user,
    timeoutMs: NAMING_TIMEOUT_MS,
    maxOutputTokens: NAMING_MAX_OUTPUT_TOKENS,
  });
  return result.failed === undefined ? parseDescriptionReply(result.text) : undefined;
}

// ---- many collections at once: the upgrade from before collection-naming (owner, 2026-10-18) ----

export const MAX_BATCH_COLLECTIONS = 100;
/** Words sent per collection: enough to tell the topic, few enough for 100 collections. */
export const MAX_BATCH_WORDS = 30;
const BATCH_TIMEOUT_MS = 120_000;
const BATCH_MAX_OUTPUT_TOKENS = 16_000;
const MAX_ID_LENGTH = 100;

export interface BatchItem {
  id: string;
  words: NamingWord[];
  name: boolean;
  description: boolean;
}
export interface BatchRequest {
  collections: BatchItem[];
  model: string;
}
export interface BatchResult {
  id: string;
  name?: string;
  description?: string;
}

/** `{collections: [{id, words, want: ["name"|"description", ...]}], model?}`, or the reason it is not one. */
export function parseBatchRequest(body: unknown): BatchRequest | { error: string; code?: string } {
  if (!isRecord(body) || !Array.isArray(body.collections)) return { error: "collections must be a list" };
  if (body.collections.length === 0) return { error: "collections must not be empty" };
  if (body.collections.length > MAX_BATCH_COLLECTIONS) return { error: `at most ${MAX_BATCH_COLLECTIONS} collections` };
  const collections: BatchItem[] = [];
  const seen = new Set<string>();
  for (const item of body.collections) {
    if (!isRecord(item)) return { error: "each collection needs an id, words and want" };
    const id = typeof item.id === "string" ? item.id.trim() : "";
    if (!id || id.length > MAX_ID_LENGTH || seen.has(id)) return { error: "each collection needs its own id" };
    seen.add(id);
    const want = Array.isArray(item.want) ? item.want : [];
    const name = want.includes("name");
    const description = want.includes("description");
    if (!name && !description) return { error: "want must hold name or description" };
    const words = parseNamingRequest({ words: Array.isArray(item.words) ? item.words.slice(0, MAX_BATCH_WORDS) : item.words });
    if ("error" in words) return { error: `collection ${id}: ${words.error}` };
    collections.push({ id, words: words.words, name, description });
  }
  const model = body.model ?? DEFAULT_NAMING_MODEL;
  if (typeof model !== "string" || !isNamingModel(model)) return { error: "That AI is not offered", code: "not_offered" };
  return { collections, model };
}

export function batchPrompt({ collections }: BatchRequest): { system: string; user: string } {
  return {
    system: [
      "You give names and descriptions to several of a learner's word lists at once.",
      "The user message is JSON: \"collections\", each with an \"id\", its English \"words\" (each with an optional \"translation\") and \"want\": what to write for it.",
      "A \"name\": one short, plain English name of one to four words (at most 40 characters), in title case, after what its words have in common, such as \"Kitchen Tools\"; when they share no topic, what they are best (\"Everyday Verbs\"). No quotes, no emoji, no full stop, no word \"vocabulary\".",
      "A \"description\": one or two plain English sentences (at most 200 characters) saying what the words are about and where they would be useful. Do not list the words, do not address the learner.",
      "Write only what each collection's \"want\" asks for, and give every collection its own answer even when two look alike.",
      "Reply with ONLY a strict JSON object, no prose and no code fences: {\"collections\": [{\"id\": \"<id>\", \"name\": \"...\", \"description\": \"...\"}]}",
    ].join("\n"),
    user: JSON.stringify({
      collections: collections.map(({ id, words, name, description }) => ({
        id,
        words,
        want: [...(name ? ["name"] : []), ...(description ? ["description"] : [])],
      })),
    }),
  };
}

/** The answers in the AI's reply for the asked ids only, each cleaned as the single routes clean it. */
export function parseBatchReply(request: BatchRequest, reply: string): BatchResult[] | undefined {
  const trimmed = reply.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  let list: unknown;
  try {
    const parsed: unknown = JSON.parse(fenced ? fenced[1] : trimmed);
    list = isRecord(parsed) ? parsed.collections : undefined;
  } catch {
    return undefined;
  }
  if (!Array.isArray(list)) return undefined;
  const asked = new Map(request.collections.map((c) => [c.id, c]));
  const results = new Map<string, BatchResult>();
  for (const raw of list) {
    if (!isRecord(raw) || typeof raw.id !== "string") continue;
    const item = asked.get(raw.id);
    if (!item || results.has(raw.id)) continue;
    const result: BatchResult = { id: raw.id };
    if (item.name && typeof raw.name === "string") {
      const name = parseNamingReply(JSON.stringify({ name: raw.name }));
      if (name) result.name = name;
    }
    if (item.description && typeof raw.description === "string") {
      const description = parseDescriptionReply(JSON.stringify({ description: raw.description }));
      if (description) result.description = description;
    }
    if (result.name || result.description) results.set(raw.id, result);
  }
  return [...results.values()];
}

export async function autofillCollections(env: TextEnv, request: BatchRequest): Promise<BatchResult[] | undefined> {
  const { system, user } = batchPrompt(request);
  const result = await writeText(env, {
    model: request.model,
    system,
    user,
    timeoutMs: BATCH_TIMEOUT_MS,
    maxOutputTokens: BATCH_MAX_OUTPUT_TOKENS,
  });
  return result.failed === undefined ? parseBatchReply(request, result.text) : undefined;
}
