import type { Env } from "../env";
import {
  SESSION_TTL_SECONDS,
  detailOf,
  type DeclaredSource,
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

const INSERT_SESSION = `INSERT INTO sessions (id, created_at, expires_at, detail, edit_token_hash) VALUES (?1, ?2, ?3, ?4, ?5)`;
const INSERT_ROW = `INSERT INTO rows (session_id, id, position, source_id, word, translation, definition)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`;
const INSERT_ROW_IF_ABSENT = `INSERT OR IGNORE INTO rows (session_id, id, position, word, translation, definition)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6)`;
const INSERT_PENDING_SOURCE = `INSERT INTO sources (session_id, id, ord) VALUES (?1, ?2, ?3)`;

function isExpired(expiresAt: string, now = Date.now()): boolean {
  return Date.parse(expiresAt) < now;
}

/** A random republish token (ADR-0008): 32 bytes, base64url. Only its hash is stored. */
function newEditToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hashEditToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** What a publish needs besides the session id: the rows and the photos they were recognised from. */
export interface PublishInput {
  entries: SessionEntry[];
  sources: DeclaredSource[];
  detail: SessionDetail;
}

/** A published session and the token that lets its publisher republish it. */
export interface Published {
  session: StoredSession;
  editToken: string;
}

/**
 * Inserts the rows (a server id each: the app does not id its rows yet) and the
 * declared photos as pending slots. Every translation and definition received
 * is stored, whatever `detail` says (AC-27). Cells start at revision 0; a
 * republish then lifts them to the revision that replaced the list.
 */
function insertContent(env: Env, sessionId: string, input: PublishInput): D1PreparedStatement[] {
  return [
    ...input.entries.map((entry, position) =>
      env.DB.prepare(INSERT_ROW).bind(
        sessionId,
        crypto.randomUUID(),
        position,
        entry.sourceId ?? null,
        entry.word,
        entry.translation,
        entry.definition ?? ""
      )
    ),
    ...input.sources.map((source) => env.DB.prepare(INSERT_PENDING_SOURCE).bind(sessionId, source.id, source.order)),
  ];
}

/**
 * Creates a session with a random id (the link is the page's only credential),
 * its rows in order and its declared photos as pending slots.
 */
export async function createSession(env: Env, input: PublishInput): Promise<Published> {
  const now = Date.now();
  const id = crypto.randomUUID();
  const editToken = newEditToken();
  await env.DB.batch([
    env.DB.prepare(INSERT_SESSION).bind(
      id,
      new Date(now).toISOString(),
      new Date(now + SESSION_TTL_SECONDS * 1000).toISOString(),
      input.detail,
      await hashEditToken(editToken)
    ),
    ...insertContent(env, id, input),
  ]);
  const session = await readSession(env, id);
  if (!session) throw new Error(`session ${id} vanished right after it was created`);
  return { session, editToken };
}

/**
 * Overwrites a live session's rows and photo slots under the same link
 * (ADR-0008) when `editToken` is the one it was published with. Keeps
 * `expires_at` (D4), raises the revision and records it as `replaced_rev`, so a
 * page whose cursor is below it reloads the list. Revisions only go up. Returns
 * null for an unknown or expired id, a KV-imported link (no token) or a wrong
 * token -- the caller then publishes a new link.
 */
export async function republishSession(
  env: Env,
  publishedId: string,
  editToken: string,
  input: PublishInput
): Promise<Published | null> {
  const tokenHash = await hashEditToken(editToken);
  const current = await env.DB.prepare(`SELECT expires_at FROM sessions WHERE id = ?1 AND edit_token_hash = ?2`)
    .bind(publishedId, tokenHash)
    .first<{ expires_at: string }>();
  if (!current || isExpired(current.expires_at)) return null;

  // One batch is one transaction: pages never see the old rows mixed with the new.
  await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1, replaced_rev = rev + 1, detail = ?2 WHERE id = ?1`).bind(
      publishedId,
      input.detail
    ),
    env.DB.prepare(`DELETE FROM rows WHERE session_id = ?1`).bind(publishedId),
    env.DB.prepare(`DELETE FROM sources WHERE session_id = ?1`).bind(publishedId),
    ...insertContent(env, publishedId, input),
    env.DB.prepare(
      `UPDATE rows SET word_rev = s.rev, translation_rev = s.rev, definition_rev = s.rev
       FROM (SELECT rev FROM sessions WHERE id = ?1) AS s
       WHERE session_id = ?1`
    ).bind(publishedId),
  ]);
  const session = await readSession(env, publishedId);
  if (!session) return null;
  return { session, editToken };
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

export type PhotoUpload = "stored" | "already_arrived" | "not_declared";

/**
 * Stores the bytes of a declared photo (ADR-0006) and marks its slot arrived
 * at a new session revision, so polling pages swap the placeholder for it.
 * Only a slot this session declared can receive bytes; a slot that has already
 * arrived is left as it is, so the app's retries are safe to repeat. Two
 * uploads racing for one pending slot both write the same bytes to R2; the
 * conditional updates let only one of them raise the revision.
 */
export async function storeDeclaredPhoto(
  env: Env,
  session: StoredSession,
  sourceId: string,
  bytes: ArrayBuffer,
  mediaType: string
): Promise<PhotoUpload> {
  if (!env.SOURCES) throw new Error("SOURCES binding is not configured");
  const slot = session.sources.find((source) => source.id === sourceId);
  if (!slot) return "not_declared";
  if (slot.status === "arrived") return "already_arrived";

  await env.SOURCES.put(r2Key(session.id, sourceId), bytes, {
    httpMetadata: { contentType: mediaType },
  });
  const pending = `EXISTS (SELECT 1 FROM sources WHERE session_id = ?1 AND id = ?2 AND status = 'pending')`;
  await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1 AND ${pending}`).bind(session.id, sourceId),
    env.DB.prepare(
      `UPDATE sources SET status = 'arrived', media_type = ?3, bytes = ?4,
         arrived_rev = (SELECT rev FROM sessions WHERE id = ?1)
       WHERE session_id = ?1 AND id = ?2 AND status = 'pending'`
    ).bind(session.id, sourceId, mediaType, bytes.byteLength),
  ]);
  return "stored";
}

/**
 * The bytes of one photo, only while it is an arrived slot of this live
 * session. A guessed id, a pending slot, a slot dropped by a republish and a
 * session published without photos all read as null (AC-24), whatever R2 holds.
 */
export async function getSourceObject(env: Env, sessionId: string, sourceId: string): Promise<R2ObjectBody | null> {
  if (!env.SOURCES) return null;
  const session = await loadSession(env, sessionId);
  const slot = session?.sources.find((source) => source.id === sourceId);
  if (!slot || slot.status !== "arrived") return null;
  return env.SOURCES.get(r2Key(sessionId, sourceId));
}

export function hasSourceStorage(env: Env): boolean {
  return env.SOURCES !== undefined;
}
