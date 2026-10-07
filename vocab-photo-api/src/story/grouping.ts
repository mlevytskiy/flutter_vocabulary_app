// Grouping (ADR-0005, sad §6 S-01): the fixed AI (Haiku 4.5) splits a session's words into
// topical groups of 7 to 19 with short names. The Worker only asks and parses; the app
// validates the split. Not counted against the story allowance.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { GROUPING_MODEL } from "./models.ts";
import { writeText, type TextEnv } from "./providers/text.ts";

/** A session's words to learn; a very large session is refused rather than sent. */
export const MAX_GROUPING_WORDS = 500;
const MAX_WORD_LENGTH = 200;
const MAX_ID_LENGTH = 100;
const MAX_NAME_LENGTH = 200;

export interface GroupingWord {
  rowId: string;
  word: string;
}
/** A group without a story: it keeps its name and words and may only gain words. */
export interface KeepGroup {
  id: string;
  name: string;
  rowIds: string[];
}
export interface GroupingRequest {
  words: GroupingWord[];
  keep: KeepGroup[];
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

function text(value: unknown, max: number): string | undefined {
  return typeof value === "string" && value.trim() !== "" && value.length <= max ? value : undefined;
}

/** `{words: [{rowId, word}], keep?: [{id, name, rowIds}]}`, or the reason it is not one. */
export function parseGroupingRequest(body: unknown): GroupingRequest | { error: string } {
  if (!isRecord(body) || !Array.isArray(body.words)) return { error: "words must be a list" };
  if (body.words.length === 0) return { error: "words must not be empty" };
  if (body.words.length > MAX_GROUPING_WORDS) return { error: `at most ${MAX_GROUPING_WORDS} words` };

  const words: GroupingWord[] = [];
  const seen = new Set<string>();
  for (const item of body.words) {
    const rowId = isRecord(item) ? text(item.rowId, MAX_ID_LENGTH) : undefined;
    const word = isRecord(item) ? text(item.word, MAX_WORD_LENGTH) : undefined;
    if (!rowId || !word) return { error: "each word needs a rowId and a word" };
    if (seen.has(rowId)) return { error: "a rowId is used twice" };
    seen.add(rowId);
    words.push({ rowId, word });
  }

  const rawKeep = body.keep ?? [];
  if (!Array.isArray(rawKeep)) return { error: "keep must be a list" };
  const keep: KeepGroup[] = [];
  for (const item of rawKeep) {
    const id = isRecord(item) ? text(item.id, MAX_ID_LENGTH) : undefined;
    const name = isRecord(item) ? text(item.name, MAX_NAME_LENGTH) : undefined;
    const rowIds = isRecord(item) ? item.rowIds : undefined;
    if (!id || !name || !Array.isArray(rowIds) || !rowIds.every((r) => typeof r === "string")) {
      return { error: "each keep group needs an id, a name and rowIds" };
    }
    keep.push({ id, name, rowIds: rowIds as string[] });
  }
  return { words, keep };
}

/** The grouping prompt. The user turn is the request as JSON, so ids and words cannot be misread. */
export function groupingPrompt({ words, keep }: GroupingRequest): { system: string; user: string } {
  return {
    system: [
      "You split a learner's English words into topical groups for learning, and give each group a short name.",
      "The user message is JSON: \"words\" (each with a \"rowId\" and an English \"word\") and \"keep\" (existing groups with an \"id\", a \"name\" and their \"rowIds\").",
      "Put every word in exactly one group. Make topical groups of 7 to 19 words, as even in size as you can.",
      "Each group in \"keep\" stays as it is: same id, same name, and all of its rowIds. You may only add other words to it.",
      "Give each new group a short, plain name in English of one to three words.",
      "Reply with ONLY a strict JSON object, no prose and no code fences, in this shape:",
      "{\"groups\": [{\"id\": \"<a keep group's id, only for keep groups>\", \"name\": \"<short name>\", \"rowIds\": [\"<rowId>\", ...]}]}",
    ].join("\n"),
    user: JSON.stringify({ words, keep }),
  };
}

/** The reply's JSON (a fenced block is allowed), or undefined when it is not an object with a groups list. */
export function parseGroupingReply(reply: string): { groups: unknown[] } | undefined {
  const trimmed = reply.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  try {
    const parsed: unknown = JSON.parse(fenced ? fenced[1] : trimmed);
    return isRecord(parsed) && Array.isArray(parsed.groups) ? (parsed as { groups: unknown[] }) : undefined;
  } catch {
    return undefined;
  }
}

/** Asks the fixed AI for a split; `undefined` when it failed or its answer is not usable JSON. */
export async function groupWords(env: TextEnv, request: GroupingRequest): Promise<{ groups: unknown[] } | undefined> {
  const { system, user } = groupingPrompt(request);
  const result = await writeText(env, { model: GROUPING_MODEL, system, user });
  if (result.failed !== undefined) return undefined;
  return parseGroupingReply(result.text);
}
