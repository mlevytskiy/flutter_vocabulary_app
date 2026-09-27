import type { Env } from "../env";
import {
  SESSION_TTL_SECONDS,
  detailOf,
  type SessionDetail,
  type SessionDocument,
  type SessionEntry,
  type StoredRow,
  type StoredSession,
  type StoredSource,
} from "./types";

/**
 * The D1 repository for published sessions (good-looking-web, ADR-0003).
 * Schema: `migrations/0001_sessions.sql`. New publishes write D1 only; the
 * `SESSIONS` KV namespace is read once per pre-feature link, on its first
 * open, and never written again.
 */

const kvKey = (sessionId: string) => `session:${sessionId}`;
const r2Key = (sessionId: string, sourceId: string) => `sessions/${sessionId}/sources/${sourceId}`;

const INSERT_SESSION = `INSERT INTO sessions (id, created_at, expires_at, detail) VALUES (?1, ?2, ?3, ?4)`;
const ROW_VALUES = `rows (session_id, id, position, word, translation, definition) VALUES (?1, ?2, ?3, ?4, ?5, ?6)`;
const INSERT_ROW = `INSERT INTO ${ROW_VALUES}`;
const INSERT_ROW_IF_ABSENT = `INSERT OR IGNORE INTO ${ROW_VALUES}`;

function isExpired(expiresAt: string, now = Date.now()): boolean {
  return Date.parse(expiresAt) < now;
}

/**
 * Creates a session with a random id (the link is the page's only credential)
 * and one row per entry, in order. The app does not id its rows yet, so every
 * row gets a server id. Every translation and definition received is stored,
 * whatever `detail` says (AC-27).
 */
export async function createSession(env: Env, entries: SessionEntry[], detail: SessionDetail): Promise<StoredSession> {
  const now = Date.now();
  const id = crypto.randomUUID();
  const createdAt = new Date(now).toISOString();
  const expiresAt = new Date(now + SESSION_TTL_SECONDS * 1000).toISOString();
  const rows: StoredRow[] = entries.map((entry, position) => ({
    id: crypto.randomUUID(),
    position,
    sourceId: null,
    word: entry.word,
    wordRev: 0,
    translation: entry.translation,
    translationRev: 0,
    definition: entry.definition ?? "",
    definitionRev: 0,
  }));
  await env.DB.batch([
    env.DB.prepare(INSERT_SESSION).bind(id, createdAt, expiresAt, detail),
    ...rows.map((row) =>
      env.DB.prepare(INSERT_ROW).bind(id, row.id, row.position, row.word, row.translation, row.definition)
    ),
  ]);
  return { id, createdAt, expiresAt, rev: 0, replacedRev: 0, detail, rows, sources: [] };
}

/**
 * Loads a live session with its live rows and photo slots, or null when the id
 * is unknown or the session has expired -- the caller answers both the same
 * way (AC-32). A link published before this feature is imported from KV on its
 * first open, keeping its original expiry.
 */
export async function loadSession(env: Env, sessionId: string): Promise<StoredSession | null> {
  let session = await readSession(env, sessionId);
  if (!session && (await importLegacySession(env, sessionId))) {
    session = await readSession(env, sessionId);
  }
  if (!session || isExpired(session.expiresAt)) return null;
  return session;
}

interface SessionRecord {
  id: string;
  created_at: string;
  expires_at: string;
  rev: number;
  replaced_rev: number;
  detail: SessionDetail;
}

interface RowRecord {
  id: string;
  position: number;
  source_id: string | null;
  word: string;
  word_rev: number;
  translation: string;
  translation_rev: number;
  definition: string;
  definition_rev: number;
}

interface SourceRecord {
  id: string;
  ord: number;
  media_type: string | null;
  bytes: number | null;
  status: "pending" | "arrived";
  arrived_rev: number | null;
}

/** One batch, so the session, its rows and its slots are read at the same revision. */
async function readSession(env: Env, sessionId: string): Promise<StoredSession | null> {
  const [sessions, rows, sources] = await env.DB.batch([
    env.DB.prepare(
      `SELECT id, created_at, expires_at, rev, replaced_rev, detail FROM sessions WHERE id = ?1`
    ).bind(sessionId),
    env.DB.prepare(
      `SELECT id, position, source_id, word, word_rev, translation, translation_rev, definition, definition_rev
       FROM rows WHERE session_id = ?1 AND deleted_at_rev IS NULL ORDER BY position`
    ).bind(sessionId),
    env.DB.prepare(
      `SELECT id, ord, media_type, bytes, status, arrived_rev FROM sources WHERE session_id = ?1 ORDER BY ord`
    ).bind(sessionId),
  ]);
  const session = (sessions.results as SessionRecord[])[0];
  if (!session) return null;
  return {
    id: session.id,
    createdAt: session.created_at,
    expiresAt: session.expires_at,
    rev: session.rev,
    replacedRev: session.replaced_rev,
    detail: session.detail,
    rows: (rows.results as RowRecord[]).map(
      (row): StoredRow => ({
        id: row.id,
        position: row.position,
        sourceId: row.source_id,
        word: row.word,
        wordRev: row.word_rev,
        translation: row.translation,
        translationRev: row.translation_rev,
        definition: row.definition,
        definitionRev: row.definition_rev,
      })
    ),
    sources: (sources.results as SourceRecord[]).map(
      (source): StoredSource => ({
        id: source.id,
        ord: source.ord,
        mediaType: source.media_type,
        bytes: source.bytes,
        status: source.status,
        arrivedRev: source.arrived_rev,
      })
    ),
  };
}

/**
 * Copies a pre-feature KV document into D1 with its original dates, detail,
 * rows and photos (their bytes stay where they are in R2). Returns false when
 * KV has no live document under the id. Row ids are derived from the row's
 * place and every insert ignores an existing key, so two first opens racing
 * each other import the same session once.
 */
async function importLegacySession(env: Env, sessionId: string): Promise<boolean> {
  const doc = await env.SESSIONS.get<SessionDocument>(kvKey(sessionId), "json");
  if (!doc || isExpired(doc.expiresAt)) return false;
  await env.DB.batch([
    env.DB.prepare(
      `INSERT OR IGNORE INTO sessions (id, created_at, expires_at, detail) VALUES (?1, ?2, ?3, ?4)`
    ).bind(sessionId, doc.createdAt, doc.expiresAt, detailOf(doc)),
    ...doc.entries.map((entry, position) =>
      env.DB.prepare(INSERT_ROW_IF_ABSENT).bind(
        sessionId,
        `kv-${position}`,
        position,
        entry.word,
        entry.translation,
        entry.definition ?? ""
      )
    ),
    ...doc.sources.map((source, ord) =>
      env.DB.prepare(
        `INSERT OR IGNORE INTO sources (session_id, id, ord, media_type, bytes, status, arrived_rev)
         VALUES (?1, ?2, ?3, ?4, ?5, 'arrived', 0)`
      ).bind(sessionId, source.id, ord, source.mediaType, source.bytes)
    ),
  ]);
  return true;
}

/**
 * Stores the bytes in R2, then records the photo as an arrived slot at a new
 * session revision. Kept for the app's current upload route until declared
 * photos replace it (ADR-0006).
 */
export async function addPhotoSource(
  env: Env,
  session: StoredSession,
  bytes: ArrayBuffer,
  mediaType: string
): Promise<StoredSource> {
  if (!env.SOURCES) throw new Error("SOURCES binding is not configured");
  const id = crypto.randomUUID();
  await env.SOURCES.put(r2Key(session.id, id), bytes, {
    httpMetadata: { contentType: mediaType },
  });
  const [, inserted] = await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1`).bind(session.id),
    env.DB.prepare(
      `INSERT INTO sources (session_id, id, ord, media_type, bytes, status, arrived_rev)
       SELECT ?1, ?2, (SELECT coalesce(max(ord) + 1, 0) FROM sources WHERE session_id = ?1), ?3, ?4, 'arrived', rev
       FROM sessions WHERE id = ?1
       RETURNING ord, arrived_rev`
    ).bind(session.id, id, mediaType, bytes.byteLength),
  ]);
  const { ord, arrived_rev } = (inserted.results as { ord: number; arrived_rev: number }[])[0];
  return { id, ord, mediaType, bytes: bytes.byteLength, status: "arrived", arrivedRev: arrived_rev };
}

export async function getSourceObject(env: Env, sessionId: string, sourceId: string): Promise<R2ObjectBody | null> {
  if (!env.SOURCES) return null;
  return env.SOURCES.get(r2Key(sessionId, sourceId));
}

export function hasSourceStorage(env: Env): boolean {
  return env.SOURCES !== undefined;
}
