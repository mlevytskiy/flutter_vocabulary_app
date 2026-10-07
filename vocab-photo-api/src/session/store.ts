import type { Env } from "../env";
import {
  MAX_DIALOGUES_PER_SESSION,
  deleteDialogueStatements,
  insertDialogueStatements,
  isRepeatAppend,
  pictureKey,
  type DeclaredDialogue,
} from "./dialogues";
import { logEvent } from "../log";
import {
  MAX_ENTRIES,
  MAX_SESSION_JSON_BYTES,
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
// A set has no bytes: it is arrived at the publish revision (ADR-0006, sad §6 F4).
const INSERT_SET_SOURCE = `INSERT INTO sources (session_id, id, ord, kind, name, url, status, arrived_rev)
  VALUES (?1, ?2, ?3, 'set', ?4, ?5, 'arrived', (SELECT rev FROM sessions WHERE id = ?1))`;

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
  /** Where each kept entry stood in the list the app sent; dialogues point at those positions. */
  entryIndexes?: number[];
  sources: DeclaredSource[];
  detail: SessionDetail;
  /** Film dialogues, stored with the rows (ADR-0005). Absent from older apps. */
  dialogues?: DeclaredDialogue[];
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
  const rowIds = input.entries.map(() => crypto.randomUUID());
  const rowIdByEntryIndex = new Map(rowIds.map((rowId, position) => [input.entryIndexes?.[position] ?? position, rowId]));
  return [
    ...input.entries.map((entry, position) =>
      env.DB.prepare(INSERT_ROW).bind(
        sessionId,
        rowIds[position],
        position,
        entry.sourceId ?? null,
        entry.word,
        entry.translation,
        entry.definition ?? ""
      )
    ),
    ...input.sources.map((source) =>
      source.kind === "set"
        ? env.DB.prepare(INSERT_SET_SOURCE).bind(sessionId, source.id, source.order, source.name, source.url)
        : env.DB.prepare(INSERT_PENDING_SOURCE).bind(sessionId, source.id, source.order)
    ),
    ...insertDialogueStatements(env, sessionId, input.dialogues ?? [], rowIdByEntryIndex),
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

  const oldPictures = await env.DB.prepare(
    `SELECT id FROM dialogues WHERE session_id = ?1 AND picture_arrived_rev IS NOT NULL`
  )
    .bind(publishedId)
    .all<{ id: string }>();

  // One batch is one transaction: pages never see the old rows mixed with the new.
  await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1, replaced_rev = rev + 1, detail = ?2 WHERE id = ?1`).bind(
      publishedId,
      input.detail
    ),
    env.DB.prepare(`DELETE FROM rows WHERE session_id = ?1`).bind(publishedId),
    env.DB.prepare(`DELETE FROM sources WHERE session_id = ?1`).bind(publishedId),
    ...deleteDialogueStatements(env, publishedId),
    ...insertContent(env, publishedId, input),
    env.DB.prepare(
      `UPDATE rows SET word_rev = s.rev, translation_rev = s.rev, definition_rev = s.rev
       FROM (SELECT rev FROM sessions WHERE id = ?1) AS s
       WHERE session_id = ?1`
    ).bind(publishedId),
  ]);
  await deleteGonePictures(env, publishedId, oldPictures.results, input.dialogues ?? []);
  const session = await readSession(env, publishedId);
  if (!session) return null;
  return { session, editToken };
}

/**
 * Deletes the scene-picture objects of dialogues a republish dropped. Best
 * effort: the dialogue rows are already gone, so a picture that lingers in R2
 * is unreachable and ages out with the bucket's lifecycle rule. A dialogue the
 * republish carries again keeps its object; its bytes come again with the
 * publish, like a photo's.
 */
async function deleteGonePictures(
  env: Env,
  sessionId: string,
  old: readonly { id: string }[],
  carried: readonly DeclaredDialogue[]
): Promise<void> {
  if (!env.SOURCES || old.length === 0) return;
  const keep = new Set(carried.map((dialogue) => dialogue.id));
  for (const { id } of old) {
    if (keep.has(id)) continue;
    try {
      await env.SOURCES.delete(pictureKey(sessionId, id));
    } catch {
      logEvent("scene picture cleanup failed", { sessionId, dialogueId: id });
    }
  }
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

/**
 * Whether a session is live, reading only its `sessions` row -- what every page
 * write checks before touching the rows. An id D1 does not know yet may still
 * be a pre-feature KV link, which `loadSession` imports.
 */
export async function isLiveSession(env: Env, sessionId: string): Promise<boolean> {
  const record = await env.DB.prepare(`SELECT expires_at FROM sessions WHERE id = ?1`)
    .bind(sessionId)
    .first<{ expires_at: string }>();
  if (record) return !isExpired(record.expires_at);
  return (await loadSession(env, sessionId)) !== null;
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
  kind: "photo" | "set";
  name: string | null;
  url: string | null;
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
      `SELECT id, ord, kind, name, url, media_type, bytes, status, arrived_rev FROM sources WHERE session_id = ?1 ORDER BY ord`
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
        kind: source.kind,
        name: source.name,
        url: source.url,
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
    ...doc.sources.flatMap((source, ord) =>
      source.kind !== "photo" ? [] : [
      env.DB.prepare(
        `INSERT OR IGNORE INTO sources (session_id, id, ord, media_type, bytes, status, arrived_rev)
         VALUES (?1, ?2, ?3, ?4, ?5, 'arrived', 0)`
      ).bind(sessionId, source.id, ord, source.mediaType, source.bytes)]
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
  const slot = session.sources.find((source) => source.id === sourceId && source.kind === "photo");
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
  const slot = session?.sources.find((source) => source.id === sourceId && source.kind === "photo");
  if (!slot || slot.status !== "arrived") return null;
  return env.SOURCES.get(r2Key(sessionId, sourceId));
}

export function hasSourceStorage(env: Env): boolean {
  return env.SOURCES !== undefined;
}

type Authorized = { ok: true; rev: number } | { ok: false; outcome: "gone" | "forbidden" };

/**
 * Whether `editToken` is the one this live session was published with. An
 * unknown or expired id is "gone" (answered like the page does, AC-32); a
 * missing or wrong token, or a link with no token (a pre-feature KV import), is
 * "forbidden". Only the token's hash is stored and compared.
 */
async function authorizeEdit(env: Env, sessionId: string, editToken: string | null): Promise<Authorized> {
  const record = await env.DB.prepare(`SELECT expires_at, rev, edit_token_hash FROM sessions WHERE id = ?1`)
    .bind(sessionId)
    .first<{ expires_at: string; rev: number; edit_token_hash: string | null }>();
  if (!record || isExpired(record.expires_at)) return { ok: false, outcome: "gone" };
  if (!editToken || !record.edit_token_hash || (await hashEditToken(editToken)) !== record.edit_token_hash) {
    return { ok: false, outcome: "forbidden" };
  }
  return { ok: true, rev: record.rev };
}

/** What an import adds to a published session (ADR-0005): its rows and the dialogues about them. */
export interface AppendInput {
  importId: string;
  entries: SessionEntry[];
  entryIndexes: number[];
  dialogues: DeclaredDialogue[];
}

export type Append =
  | { outcome: "gone" | "forbidden" | "list_full" }
  | { outcome: "appended" | "repeat"; rev: number };

const APPEND_ROW = `INSERT INTO rows
  (session_id, id, position, word, word_rev, translation, translation_rev, definition, definition_rev)
  VALUES (?1, ?2, (SELECT coalesce(max(position), -1) + 1 FROM rows WHERE session_id = ?1), ?3,
    (SELECT rev FROM sessions WHERE id = ?1), ?4, (SELECT rev FROM sessions WHERE id = ?1), ?5,
    (SELECT rev FROM sessions WHERE id = ?1))`;

/**
 * Adds an import's rows after the session's rows and its dialogues after its
 * dialogues, all at one new revision, without touching what is there. An import
 * already seen -- its id is in `dialogue_imports`, or one of its dialogue ids is
 * in the session because a republish carried it -- adds nothing and answers the
 * same. The import id is recorded in the batch that appends; a racing twin
 * collides on its key, the batch rolls back, and it reads as the repeat it is.
 */
export async function appendToSession(
  env: Env,
  sessionId: string,
  editToken: string | null,
  input: AppendInput
): Promise<Append> {
  const auth = await authorizeEdit(env, sessionId, editToken);
  if (!auth.ok) return { outcome: auth.outcome };
  const dialogueIds = input.dialogues.map((dialogue) => dialogue.id);
  const repeat = async (): Promise<Append | null> =>
    (await isRepeatAppend(env, sessionId, input.importId, dialogueIds))
      ? { outcome: "repeat", rev: await currentRev(env, sessionId) }
      : null;
  const seen = await repeat();
  if (seen) return seen;

  const held = await env.DB.prepare(
    `SELECT
       (SELECT count(*) FROM rows WHERE session_id = ?1 AND deleted_at_rev IS NULL) AS rows,
       (SELECT count(*) FROM dialogues WHERE session_id = ?1) AS dialogues,
       (SELECT coalesce(sum(length(CAST(word AS BLOB)) + length(CAST(translation AS BLOB)) + length(CAST(definition AS BLOB))), 0)
          FROM rows WHERE session_id = ?1 AND deleted_at_rev IS NULL) AS bytes`
  )
    .bind(sessionId)
    .first<{ rows: number; dialogues: number; bytes: number }>();
  const encoder = new TextEncoder();
  const added = input.entries.reduce(
    (sum, entry) =>
      sum + encoder.encode(entry.word).length + encoder.encode(entry.translation).length + encoder.encode(entry.definition ?? "").length,
    0
  );
  if (
    !held ||
    held.rows + input.entries.length > MAX_ENTRIES ||
    held.dialogues + input.dialogues.length > MAX_DIALOGUES_PER_SESSION ||
    held.bytes + added > MAX_SESSION_JSON_BYTES
  ) {
    return { outcome: "list_full" };
  }

  const rowIds = input.entries.map(() => crypto.randomUUID());
  const rowIdByEntryIndex = new Map(rowIds.map((rowId, position) => [input.entryIndexes[position] ?? position, rowId]));
  try {
    await env.DB.batch([
      env.DB.prepare(`INSERT INTO dialogue_imports (session_id, import_id) VALUES (?1, ?2)`).bind(sessionId, input.importId),
      env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1`).bind(sessionId),
      ...input.entries.map((entry, position) =>
        env.DB.prepare(APPEND_ROW).bind(sessionId, rowIds[position], entry.word, entry.translation, entry.definition ?? "")
      ),
      ...insertDialogueStatements(env, sessionId, input.dialogues, rowIdByEntryIndex, { afterExisting: true }),
    ]);
  } catch (error) {
    // A twin of this import got in first (or a republish carried its dialogues): that is the repeat.
    const twin = await repeat();
    if (twin) return twin;
    throw error;
  }
  return { outcome: "appended", rev: await currentRev(env, sessionId) };
}

async function currentRev(env: Env, sessionId: string): Promise<number> {
  const record = await env.DB.prepare(`SELECT rev FROM sessions WHERE id = ?1`).bind(sessionId).first<{ rev: number }>();
  return record?.rev ?? 0;
}

export type PictureUpload = "stored" | "already_arrived" | "not_declared" | "gone" | "forbidden";

/**
 * Stores a dialogue's scene picture (bytes in R2 under the session's prefix) and
 * marks it arrived at a new session revision, so polling pages swap it in. Only
 * the app holding the edit token may. Once the bytes have arrived a repeat is
 * left as it is, so the app's retries are safe.
 */
export async function storeDialoguePicture(
  env: Env,
  sessionId: string,
  editToken: string | null,
  dialogueId: string,
  bytes: ArrayBuffer,
  mediaType: string
): Promise<PictureUpload> {
  if (!env.SOURCES) throw new Error("SOURCES binding is not configured");
  const auth = await authorizeEdit(env, sessionId, editToken);
  if (!auth.ok) return auth.outcome;
  const slot = await env.DB.prepare(`SELECT picture_arrived_rev FROM dialogues WHERE session_id = ?1 AND id = ?2`)
    .bind(sessionId, dialogueId)
    .first<{ picture_arrived_rev: number | null }>();
  if (!slot) return "not_declared";
  if (slot.picture_arrived_rev !== null) return "already_arrived";

  await env.SOURCES.put(pictureKey(sessionId, dialogueId), bytes, { httpMetadata: { contentType: mediaType } });
  const pending = `EXISTS (SELECT 1 FROM dialogues WHERE session_id = ?1 AND id = ?2 AND picture_arrived_rev IS NULL)`;
  await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1 AND ${pending}`).bind(sessionId, dialogueId),
    env.DB.prepare(
      `UPDATE dialogues SET picture_media_type = ?3, picture_bytes = ?4,
         picture_arrived_rev = (SELECT rev FROM sessions WHERE id = ?1)
       WHERE session_id = ?1 AND id = ?2 AND picture_arrived_rev IS NULL`
    ).bind(sessionId, dialogueId, mediaType, bytes.byteLength),
  ]);
  return "stored";
}

/**
 * The bytes of a dialogue's scene picture, only while it is an arrived picture
 * of a live session. A guessed id, a picture not yet arrived and an expired
 * session all read as null, whatever R2 holds.
 */
export async function getDialoguePictureObject(
  env: Env,
  sessionId: string,
  dialogueId: string
): Promise<R2ObjectBody | null> {
  if (!env.SOURCES) return null;
  const record = await env.DB.prepare(
    `SELECT d.picture_arrived_rev AS arrived, s.expires_at AS expires_at
     FROM dialogues d JOIN sessions s ON s.id = d.session_id WHERE d.session_id = ?1 AND d.id = ?2`
  )
    .bind(sessionId, dialogueId)
    .first<{ arrived: number | null; expires_at: string }>();
  if (!record || record.arrived === null || isExpired(record.expires_at)) return null;
  return env.SOURCES.get(pictureKey(sessionId, dialogueId));
}
