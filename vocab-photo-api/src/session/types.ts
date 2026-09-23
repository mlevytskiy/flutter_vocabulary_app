/**
 * The shape of a published session. Designed source-agnostic
 * (docs/idea-brief.md §7): a word table plus whatever the words came from.
 * A photo is today's source; subtitle text is a plausible next one, added as
 * another `kind` in `SessionSource`, never as a top-level field.
 */

/** One row of the table. Mirrors the app's `WordPair` and `/analyze`'s `VocabularyWord`. */
export interface SessionEntry {
  word: string;
  translation: string;
}

export interface PhotoSource {
  kind: "photo";
  /** Random id; the bytes live in R2 under `sessions/<sessionId>/sources/<id>`. */
  id: string;
  mediaType: string;
  bytes: number;
  addedAt: string;
}

/** Tagged union -- one member per source kind. Photo is the only kind today. */
export type SessionSource = PhotoSource;

export interface SessionDocument {
  id: string;
  createdAt: string;
  /** When the KV key expires (D4: 30 days after creation). Shown on the page. */
  expiresAt: string;
  entries: SessionEntry[];
  sources: SessionSource[];
}

/** D4 -- a published session and its sources live this long, then the store drops them. */
export const SESSION_TTL_SECONDS = 30 * 24 * 60 * 60;

/** Caps on the create payload. A read surface anyone can hit is fed only by a bounded write surface. */
export const MAX_SESSION_JSON_BYTES = 256 * 1024;
export const MAX_ENTRIES = 500;
export const MAX_FIELD_CHARS = 500;
export const MAX_SOURCES = 10;

export type ParsedEntries = { ok: true; entries: SessionEntry[] } | { ok: false; error: string };

/**
 * Validates the `entries` list of a create request. Blank rows (both fields
 * empty after trimming) are dropped rather than rejected -- the app keeps a
 * trailing empty row by design and must not be able to leak it onto the page.
 */
export function parseEntries(value: unknown): ParsedEntries {
  if (!Array.isArray(value)) {
    return { ok: false, error: "Body must be a JSON object with an `entries` array" };
  }
  if (value.length > MAX_ENTRIES) {
    return { ok: false, error: `At most ${MAX_ENTRIES} entries per session` };
  }
  const entries: SessionEntry[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item === null) {
      return { ok: false, error: "Each entry must be an object with `word` and `translation` strings" };
    }
    const record = item as Record<string, unknown>;
    if (typeof record.word !== "string" || typeof record.translation !== "string") {
      return { ok: false, error: "Each entry must be an object with `word` and `translation` strings" };
    }
    const word = record.word.trim();
    const translation = record.translation.trim();
    if (word.length > MAX_FIELD_CHARS || translation.length > MAX_FIELD_CHARS) {
      return { ok: false, error: `A field may hold at most ${MAX_FIELD_CHARS} characters` };
    }
    if (word === "" && translation === "") continue;
    entries.push({ word, translation });
  }
  if (entries.length === 0) {
    return { ok: false, error: "The word list is empty" };
  }
  return { ok: true, entries };
}
