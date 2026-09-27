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
  /** The declared photo this row was recognised from (ADR-0006). Absent for a typed row. */
  sourceId?: string;
}

/** A photo the app declares in its publish request (ADR-0006); its bytes follow under `id`. */
export interface DeclaredSource {
  id: string;
  order: number;
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
  /** When the session expires (D4: 30 days after creation). Shown on the page. */
  expiresAt: string;
  /** Absent before definition-mode — read it through `detailOf`. */
  detail?: SessionDetail;
  entries: SessionEntry[];
  sources: SessionSource[];
}

/**
 * One row as D1 stores it (good-looking-web, ADR-0004): a stable id, its place
 * in the table, and each cell with the session revision of its last change.
 */
export interface StoredRow {
  id: string;
  position: number;
  /** The photo slot this row was recognised from; null for a typed row. */
  sourceId: string | null;
  word: string;
  wordRev: number;
  translation: string;
  translationRev: number;
  definition: string;
  definitionRev: number;
}

/** A photo slot (ADR-0006): declared at publish, "arrived" once its bytes are in R2. */
export interface StoredSource {
  id: string;
  ord: number;
  mediaType: string | null;
  bytes: number | null;
  status: "pending" | "arrived";
  arrivedRev: number | null;
}

/** A session loaded from D1: its live rows in table order and its photo slots in order. */
export interface StoredSession {
  id: string;
  createdAt: string;
  expiresAt: string;
  /** The session revision: goes up with every write (ADR-0004). */
  rev: number;
  /** The revision of the last republish; 0 when never republished (ADR-0008). */
  replacedRev: number;
  detail: SessionDetail;
  rows: StoredRow[];
  sources: StoredSource[];
}

/**
 * The document shape the page and the AnkiDroid file are rendered from. Only
 * arrived photos are listed: a pending slot has no bytes to show yet.
 */
export function toDocument(session: StoredSession): SessionDocument {
  return {
    id: session.id,
    createdAt: session.createdAt,
    expiresAt: session.expiresAt,
    detail: session.detail,
    entries: session.rows.map((row) => {
      const entry: SessionEntry = { word: row.word, translation: row.translation };
      if (row.definition !== "") entry.definition = row.definition;
      if (row.sourceId !== null) entry.sourceId = row.sourceId;
      return entry;
    }),
    sources: session.sources
      .filter((source) => source.status === "arrived")
      .map((source) => ({
        kind: "photo",
        id: source.id,
        mediaType: source.mediaType ?? "application/octet-stream",
        bytes: source.bytes ?? 0,
        addedAt: session.createdAt,
      })),
  };
}

/** D4 -- a published session and its sources live this long, then the store drops them. */
export const SESSION_TTL_SECONDS = 30 * 24 * 60 * 60;

/** Caps on the create payload. A read surface anyone can hit is fed only by a bounded write surface. */
export const MAX_SESSION_JSON_BYTES = 256 * 1024;
export const MAX_ENTRIES = 500;
export const MAX_FIELD_CHARS = 500;
export const MAX_SOURCES = 10;

/** Session and photo ids: what the routes can address (`/s/<id>/sources/<sourceId>`). */
export const ID_PATTERN = "[A-Za-z0-9-]{1,64}";
const ID_RE = new RegExp(`^${ID_PATTERN}$`);

export type ParsedEntries = { ok: true; entries: SessionEntry[] } | { ok: false; error: string };
export type ParsedDetail = { ok: true; detail: SessionDetail } | { ok: false; error: string };
export type ParsedSources = { ok: true; sources: DeclaredSource[] } | { ok: false; error: string };
export type ParsedRepublish =
  | { ok: true; republish: { publishedId: string; editToken: string } | null }
  | { ok: false; error: string };

/**
 * `sources` is optional (older apps and "include photos" off send none, AC-24,
 * AC-26). Each photo needs an addressable id and a distinct `order`; the list
 * comes back sorted by `order`, the pager's order.
 */
export function parseSources(value: unknown): ParsedSources {
  if (value === undefined || value === null) return { ok: true, sources: [] };
  if (!Array.isArray(value)) {
    return { ok: false, error: "`sources` must be an array of `{id, order}` objects" };
  }
  if (value.length > MAX_SOURCES) {
    return { ok: false, error: `A session holds at most ${MAX_SOURCES} sources` };
  }
  const sources: DeclaredSource[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item === null) {
      return { ok: false, error: "`sources` must be an array of `{id, order}` objects" };
    }
    const record = item as Record<string, unknown>;
    if (typeof record.id !== "string" || !ID_RE.test(record.id)) {
      return { ok: false, error: "A source `id` must be 1-64 letters, digits or dashes" };
    }
    if (typeof record.order !== "number" || !Number.isInteger(record.order) || record.order < 0) {
      return { ok: false, error: "A source `order` must be a non-negative integer" };
    }
    if (sources.some((s) => s.id === record.id)) {
      return { ok: false, error: "Each source needs a distinct `id`" };
    }
    if (sources.some((s) => s.order === record.order)) {
      return { ok: false, error: "Each source needs a distinct `order`" };
    }
    sources.push({ id: record.id, order: record.order });
  }
  return { ok: true, sources: sources.sort((a, b) => a.order - b.order) };
}

/**
 * `publishedId` + `editToken` ask to overwrite an earlier link (ADR-0008). Both
 * are optional; when either is missing the publish is a first publish. Whether
 * they match a live session is the store's call, not the parser's.
 */
export function parseRepublish(body: Record<string, unknown>): ParsedRepublish {
  const { publishedId, editToken } = body;
  if (publishedId !== undefined && publishedId !== null && typeof publishedId !== "string") {
    return { ok: false, error: "`publishedId` must be a string" };
  }
  if (editToken !== undefined && editToken !== null && typeof editToken !== "string") {
    return { ok: false, error: "`editToken` must be a string" };
  }
  if (typeof publishedId !== "string" || typeof editToken !== "string") return { ok: true, republish: null };
  return { ok: true, republish: { publishedId, editToken } };
}

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
 * A row's `sourceId`, when present, must name one of `declaredSourceIds`.
 */
export function parseEntries(value: unknown, declaredSourceIds: ReadonlySet<string> = new Set()): ParsedEntries {
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
    const sourceId = record.sourceId ?? undefined;
    if (sourceId !== undefined && (typeof sourceId !== "string" || !declaredSourceIds.has(sourceId))) {
      return { ok: false, error: "An entry's `sourceId` must name a declared source" };
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
    const entry: SessionEntry = { word, translation };
    if (definition !== "") entry.definition = definition;
    if (sourceId !== undefined) entry.sourceId = sourceId;
    entries.push(entry);
  }
  if (entries.length === 0) {
    return { ok: false, error: "The word list is empty" };
  }
  return { ok: true, entries };
}
