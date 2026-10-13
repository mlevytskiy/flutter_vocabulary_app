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

/** The size rules the app enforces (lib/core/story/word_grouping.dart): keep these in step with it. */
export const MIN_GROUP_SIZE = 7;
export const MAX_GROUP_SIZE = 19;
const MAX_MERGED_NAME_LENGTH = 30;

/** How many new groups to aim for: about one per 15 words, within what 7 to 19 words per group allows. */
export function targetNewGroups(newWords: number): { target: number; min: number; max: number } {
  if (newWords < MIN_GROUP_SIZE) return { target: 0, min: 0, max: 0 };
  const min = Math.ceil(newWords / MAX_GROUP_SIZE);
  const max = Math.floor(newWords / MIN_GROUP_SIZE);
  return { target: Math.min(max, Math.max(min, Math.round(newWords / 15))), min, max };
}

/** Words that no keep group already holds: the ones the AI has to form new groups from. */
function newWordIds({ words, keep }: GroupingRequest): string[] {
  const held = new Set(keep.flatMap((g) => g.rowIds));
  return words.map((w) => w.rowId).filter((id) => !held.has(id));
}

/**
 * The grouping prompt. The user turn is the request as JSON, so ids and words cannot be misread.
 * It also states the word count and the number of new groups to make; a retry adds what was wrong
 * with the previous reply (`problems`, `previousReply`).
 */
export function groupingPrompt(
  request: GroupingRequest,
  retry?: { problems: string[]; previousReply: unknown },
): { system: string; user: string } {
  const { words, keep } = request;
  const newWords = newWordIds(request).length;
  const { target, min, max } = targetNewGroups(newWords);
  return {
    system: [
      "You split a learner's English words into topical groups for learning, and give each group a short name.",
      "The user message is JSON: \"words\" (each with a \"rowId\" and an English \"word\") and \"keep\" (existing groups with an \"id\", a \"name\" and their \"rowIds\").",
      "\"wordCount\" is the number of words; \"newWordCount\" is how many of them are in no keep group; \"newGroups\" is how many new groups to make from those (between the two numbers in \"newGroupsBetween\"), as even in size as you can.",
      "Put every word in exactly one group. Never fewer than 7, never more than 19 words in a group.",
      "Each group in \"keep\" stays as it is: same id, same name, and all of its rowIds. You may only add other words to it, and never past 19 words.",
      "Do not give new groups an id: only a keep group has an \"id\". Never invent an id.",
      "If fewer than 7 words are in no keep group, add them to a keep group that has room, or put them together in one group.",
      "Give each new group a short, plain name in English of one to three words.",
      "If the message has \"problems\", your previous reply (\"previousReply\") was rejected for them: answer again and fix every one.",
      "Reply with ONLY a strict JSON object, no prose and no code fences, in this shape:",
      "{\"groups\": [{\"id\": \"<a keep group's id, only for keep groups>\", \"name\": \"<short name>\", \"rowIds\": [\"<rowId>\", ...]}]}",
    ].join("\n"),
    user: JSON.stringify({
      wordCount: words.length,
      newWordCount: newWords,
      newGroups: target,
      newGroupsBetween: [min, max],
      words,
      keep,
      ...(retry ? { problems: retry.problems, previousReply: retry.previousReply } : {}),
    }),
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

// ---- checking and repairing the AI's split, with the app's own rules ----

/** A group of the split: `id` only for a keep group. */
export interface SplitGroup {
  id?: string;
  name: string;
  rowIds: string[];
}

const listIds = (ids: string[]) => ids.slice(0, 5).join(", ") + (ids.length > 5 ? `, and ${ids.length - 5} more` : "");

/**
 * What is wrong with `groups`, by the rules of the app's `applySplit`: every word once, nothing
 * unknown, keep groups (and only they) with their id, whole and at most 19, new groups of 7 to 19,
 * except that fewer than 7 new words altogether may wait in a smaller group. Empty means the app
 * accepts it.
 */
export function validateSplit(request: GroupingRequest, groups: unknown[]): string[] {
  const problems: string[] = [];
  const keepById = new Map(request.keep.map((g) => [g.id, g]));
  const keepIds = new Set(request.keep.flatMap((g) => g.rowIds));
  const newIds = new Set(newWordIds(request));
  const placeable = new Set([...newIds, ...keepIds]);

  const seen = new Set<string>();
  const unknown: string[] = [];
  const doubled: string[] = [];
  const seenKeeps = new Set<string>();
  const fresh: { n: number; size: number }[] = [];
  groups.forEach((raw, index) => {
    const n = index + 1;
    if (!isRecord(raw) || !Array.isArray(raw.rowIds) || !raw.rowIds.every((r) => typeof r === "string")) {
      problems.push(`group ${n} is not {"name", "rowIds": [strings]}`);
      return;
    }
    if (raw.name !== undefined && typeof raw.name !== "string") problems.push(`group ${n} has a name that is not text`);
    if (raw.id !== undefined && raw.id !== null && typeof raw.id !== "string") {
      problems.push(`group ${n} has an id that is not text`);
      return;
    }
    const rowIds = raw.rowIds as string[];
    for (const id of rowIds) {
      if (!placeable.has(id)) unknown.push(id);
      else if (seen.has(id)) doubled.push(id);
      seen.add(id);
    }
    const id = raw.id as string | null | undefined;
    if (id === undefined || id === null) {
      fresh.push({ n, size: rowIds.length });
      return;
    }
    const kept = keepById.get(id);
    if (!kept) {
      problems.push(`group ${n} has the id "${id}", which is not a keep group's id: new groups must not have an id`);
      fresh.push({ n, size: rowIds.length });
      return;
    }
    if (seenKeeps.has(id)) problems.push(`keep group "${id}" appears more than once`);
    seenKeeps.add(id);
    const has = new Set(rowIds);
    const lost = kept.rowIds.filter((r) => !has.has(r));
    if (lost.length > 0) problems.push(`keep group "${id}" must keep all its words, but lost: ${listIds(lost)}`);
    const added = rowIds.filter((r) => !kept.rowIds.includes(r));
    if (kept.rowIds.length + added.length > MAX_GROUP_SIZE) {
      problems.push(`keep group "${id}" has ${kept.rowIds.length + added.length} words, more than ${MAX_GROUP_SIZE}`);
    }
  });
  if (unknown.length > 0) problems.push(`these rowIds are not words to place: ${listIds(unknown)}`);
  if (doubled.length > 0) problems.push(`these rowIds are placed more than once: ${listIds(doubled)}`);
  const missing = [...placeable].filter((id) => !seen.has(id));
  if (missing.length > 0) problems.push(`these words are in no group: ${listIds(missing)}`);
  const lostKeeps = request.keep.filter((g) => !seenKeeps.has(g.id)).map((g) => g.id);
  if (lostKeeps.length > 0) problems.push(`keep groups missing from the reply: ${listIds(lostKeeps)}`);

  let waiting = 0;
  for (const { n, size } of fresh) {
    if (size === 0) problems.push(`new group ${n} is empty`);
    else if (size > MAX_GROUP_SIZE) problems.push(`new group ${n} has ${size} words, more than ${MAX_GROUP_SIZE}`);
    else if (size < MIN_GROUP_SIZE) {
      if (newIds.size >= MIN_GROUP_SIZE) problems.push(`new group ${n} has ${size} words, fewer than ${MIN_GROUP_SIZE}: a group needs 7 to 19 words`);
      else waiting += size;
    }
  }
  if (waiting >= MIN_GROUP_SIZE) problems.push("too many words left waiting in small groups");
  return problems;
}

interface Draft {
  name: string;
  rowIds: string[];
}

const nameOf = (value: unknown) => (typeof value === "string" && value.trim() !== "" ? value.trim() : "Words");

/** `A & B` when it is short, otherwise the larger group's name. */
function mergedName(a: Draft, b: Draft): string {
  const joined = `${a.name} & ${b.name}`;
  if (joined.length <= MAX_MERGED_NAME_LENGTH) return joined;
  return a.rowIds.length >= b.rowIds.length ? a.name : b.name;
}

/** Merges the smallest group into the smallest other one until every group has at least 7 words. */
function mergeSmall(fresh: Draft[]): void {
  for (;;) {
    if (fresh.length < 2) return;
    fresh.sort((a, b) => a.rowIds.length - b.rowIds.length);
    if (fresh[0].rowIds.length >= MIN_GROUP_SIZE) return;
    const [small, other] = fresh;
    other.name = mergedName(small, other);
    other.rowIds = [...small.rowIds, ...other.rowIds];
    fresh.shift();
  }
}

/** Cuts a group of more than 19 words into the fewest even pieces. */
function splitLarge(fresh: Draft[]): Draft[] {
  return fresh.flatMap((g) => {
    if (g.rowIds.length <= MAX_GROUP_SIZE) return [g];
    const pieces = Math.ceil(g.rowIds.length / MAX_GROUP_SIZE);
    return Array.from({ length: pieces }, (_, i) => ({
      name: `${g.name} ${i + 1}`,
      rowIds: g.rowIds.slice(Math.floor((g.rowIds.length * i) / pieces), Math.floor((g.rowIds.length * (i + 1)) / pieces)),
    }));
  });
}

/**
 * The AI's split made valid for the app, or `undefined` when even that cannot be done. Ids that are
 * not keep ids go, unknown and doubled rowIds go, missing words are added, then new groups under 7
 * are merged and ones over 19 are cut, so each new group has 7 to 19 words. A split that is already
 * valid is returned as it is.
 */
export function repairSplit(request: GroupingRequest, groups: unknown[]): SplitGroup[] | undefined {
  if (validateSplit(request, groups).length === 0) return groups as SplitGroup[];

  const keepIds = new Set(request.keep.flatMap((g) => g.rowIds));
  const wordIds = request.words.map((w) => w.rowId);
  const newIds = newWordIds(request);
  const placeable = new Set([...wordIds, ...keepIds]);
  const placed = new Set<string>();

  // Keep groups first: they are whole, with their own name, and may only gain words.
  const keeps = request.keep.map((g) => {
    const rowIds = g.rowIds.filter((id) => !placed.has(id) && (placed.add(id), true));
    return { id: g.id, name: g.name, rowIds, original: rowIds.length };
  });
  const keepOf = new Map(keeps.map((g) => [g.id, g]));
  const claimed = new Set<string>();

  let fresh: Draft[] = [];
  for (const raw of groups) {
    if (!isRecord(raw) || !Array.isArray(raw.rowIds)) continue;
    const ids = raw.rowIds.filter((id): id is string => typeof id === "string" && placeable.has(id) && !placed.has(id));
    const keep = typeof raw.id === "string" && !claimed.has(raw.id) ? keepOf.get(raw.id) : undefined;
    if (keep) {
      claimed.add(keep.id);
      for (const id of ids) {
        if (keep.rowIds.length >= MAX_GROUP_SIZE || placed.has(id)) continue;
        placed.add(id);
        keep.rowIds.push(id);
      }
      continue;
    }
    const own = ids.filter((id) => !placed.has(id) && (placed.add(id), true));
    if (own.length > 0) fresh.push({ name: nameOf(raw.name), rowIds: own });
  }
  const missing = [...placeable].filter((id) => !placed.has(id));
  if (missing.length > 0) fresh.push({ name: "More words", rowIds: missing });

  if (newIds.length < MIN_GROUP_SIZE) {
    // Too few new words to make a group: the app lets them wait together.
    if (fresh.length > 1) {
      const all = fresh.flatMap((g) => g.rowIds);
      const largest = fresh.reduce((a, b) => (b.rowIds.length > a.rowIds.length ? b : a));
      fresh = [{ name: largest.name, rowIds: all }];
    }
  } else {
    let left = fresh.reduce((n, g) => n + g.rowIds.length, 0);
    if (left > 0 && left < MIN_GROUP_SIZE) {
      // Not enough left for a group of its own: a keep group with room takes them, or the keep
      // groups give back words they gained until there are 7.
      const room = keeps.reduce((n, g) => n + MAX_GROUP_SIZE - g.rowIds.length, 0);
      if (room >= left) {
        const rest = fresh.flatMap((g) => g.rowIds);
        for (const keep of [...keeps].sort((a, b) => a.rowIds.length - b.rowIds.length)) {
          while (rest.length > 0 && keep.rowIds.length < MAX_GROUP_SIZE) keep.rowIds.push(rest.shift() as string);
        }
        fresh = [];
      } else {
        const back = fresh.flatMap((g) => g.rowIds);
        for (const keep of keeps) {
          while (back.length < MIN_GROUP_SIZE && keep.rowIds.length > keep.original) back.push(keep.rowIds.pop() as string);
        }
        fresh = [{ name: fresh[0].name, rowIds: back }];
      }
      left = fresh.reduce((n, g) => n + g.rowIds.length, 0);
    }
    if (left > 0) {
      mergeSmall(fresh);
      fresh = splitLarge(fresh);
    }
  }

  const result: SplitGroup[] = [
    ...keeps.map(({ id, name, rowIds }) => ({ id, name, rowIds })),
    ...fresh.map(({ name, rowIds }) => ({ name, rowIds })),
  ];
  return validateSplit(request, result).length === 0 ? result : undefined;
}

/**
 * Asks the fixed AI for a split that the app will accept. A bad answer is sent back once with what
 * was wrong; if the second is still bad it is repaired. `undefined` when the AI failed, its answer
 * is not usable JSON, or the split cannot be made valid.
 */
export async function groupWords(env: TextEnv, request: GroupingRequest): Promise<{ groups: unknown[] } | undefined> {
  const ask = async (retry?: { problems: string[]; previousReply: unknown }) => {
    const { system, user } = groupingPrompt(request, retry);
    const result = await writeText(env, { model: GROUPING_MODEL, system, user });
    return result.failed === undefined ? parseGroupingReply(result.text) : undefined;
  };

  const first = await ask();
  if (!first) return undefined;
  const problems = validateSplit(request, first.groups);
  if (problems.length === 0) return first;

  const second = await ask({ problems, previousReply: first.groups });
  const best = second ?? first;
  if (second && validateSplit(request, second.groups).length === 0) return second;
  const repaired = repairSplit(request, best.groups);
  return repaired ? { groups: repaired } : undefined;
}
