// Per-word hints a story start may carry (learn-welcome T9, AC-12): the sentence the word came from,
// where it came from (film name, photo) and the learner's edited translation. Pure, so it runs anywhere.

export interface WordExtra {
  word: string;
  context?: string;
  source?: string;
  translation?: string;
}

const MAX_EXTRAS = 50;
const MAX_FIELD_LENGTH = 300;
const FIELDS = ["context", "source", "translation"] as const;

/** Reads the optional `extras` of a story start: undefined is fine (old requests), a bad shape is an error text. */
export function parseExtras(value: unknown): { extras: WordExtra[] } | { error: string } {
  if (value === undefined) return { extras: [] };
  const bad = { error: `extras must be at most ${MAX_EXTRAS} objects with a word and optional context, source and translation of at most ${MAX_FIELD_LENGTH} characters` };
  if (!Array.isArray(value) || value.length > MAX_EXTRAS) return bad;
  const extras: WordExtra[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item === null || Array.isArray(item)) return bad;
    const entry = item as Record<string, unknown>;
    if (typeof entry.word !== "string" || entry.word.trim() === "" || entry.word.length > MAX_FIELD_LENGTH) return bad;
    const extra: WordExtra = { word: entry.word.trim() };
    for (const field of FIELDS) {
      const text = entry[field];
      if (text === undefined || text === null) continue;
      if (typeof text !== "string" || text.length > MAX_FIELD_LENGTH) return bad;
      if (text.trim() !== "") extra[field] = text.trim();
    }
    if (FIELDS.some((field) => extra[field] !== undefined)) extras.push(extra);
  }
  return { extras };
}
