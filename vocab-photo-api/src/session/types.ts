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
  /** English explanation (definition-mode, ADR-0004). Absent in documents published before it. */
  definition?: string;
}

/**
 * What the learner's word detail mode showed when the session was published
 * (ADR-0004). The page and its AnkiDroid file pick their columns from it; a
 * document without it (published before definition-mode) reads as "translation".
 */
export type SessionDetail = "translation" | "definition" | "both";
export const SESSION_DETAILS: readonly SessionDetail[] = ["translation", "definition", "both"];

export function detailOf(doc: { detail?: SessionDetail }): SessionDetail {
  return doc.detail && SESSION_DETAILS.includes(doc.detail) ? doc.detail : "translation";
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
  /** Absent before definition-mode — read it through `detailOf`. */
  detail?: SessionDetail;
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
export type ParsedDetail = { ok: true; detail: SessionDetail } | { ok: false; error: string };

/** `detail` is optional on the request (older apps never send it); anything else must be a known mode. */
export function parseDetail(value: unknown): ParsedDetail {
  if (value === undefined) return { ok: true, detail: "translation" };
  if (typeof value === "string" && (SESSION_DETAILS as readonly string[]).includes(value)) {
    return { ok: true, detail: value as SessionDetail };
  }
  return { ok: false, error: "`detail` must be one of: translation, definition, both" };
}

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
    if (record.definition !== undefined && typeof record.definition !== "string") {
      return { ok: false, error: "An entry's `definition` must be a string" };
    }
    const word = record.word.trim();
    const translation = record.translation.trim();
    const definition = typeof record.definition === "string" ? record.definition.trim() : "";
    if (word.length > MAX_FIELD_CHARS || translation.length > MAX_FIELD_CHARS) {
      return { ok: false, error: `A field may hold at most ${MAX_FIELD_CHARS} characters` };
    }
    if (definition.length > MAX_FIELD_CHARS) {
      // Names the word so the learner knows which definition to shorten (spec AC-19).
      return { ok: false, error: `The definition of "${word}" is too long (at most ${MAX_FIELD_CHARS} characters)` };
    }
    // Blank only when all three are empty: a definition-only row is real content.
    if (word === "" && translation === "" && definition === "") continue;
    entries.push(definition === "" ? { word, translation } : { word, translation, definition });
  }
  if (entries.length === 0) {
    return { ok: false, error: "The word list is empty" };
  }
  return { ok: true, entries };
}
