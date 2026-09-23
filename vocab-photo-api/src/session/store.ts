import type { Env } from "../env";
import { SESSION_TTL_SECONDS, type PhotoSource, type SessionDocument, type SessionEntry } from "./types";

const kvKey = (sessionId: string) => `session:${sessionId}`;
const r2Key = (sessionId: string, sourceId: string) => `sessions/${sessionId}/sources/${sourceId}`;

export async function createSession(env: Env, entries: SessionEntry[]): Promise<SessionDocument> {
  const now = Date.now();
  const doc: SessionDocument = {
    // The id is the only credential the page has: random, never sequential.
    id: crypto.randomUUID(),
    createdAt: new Date(now).toISOString(),
    expiresAt: new Date(now + SESSION_TTL_SECONDS * 1000).toISOString(),
    entries,
    sources: [],
  };
  await env.SESSIONS.put(kvKey(doc.id), JSON.stringify(doc), { expirationTtl: SESSION_TTL_SECONDS });
  return doc;
}

export async function getSession(env: Env, sessionId: string): Promise<SessionDocument | null> {
  const doc = await env.SESSIONS.get<SessionDocument>(kvKey(sessionId), "json");
  return doc ?? null;
}

/**
 * Rewrites the document keeping its original expiry -- adding a source must not
 * push the 30-day clock forward, or the sources would outlive the page they
 * belong to. Task-06's word edits should go through here for the same reason.
 */
export async function saveSession(env: Env, doc: SessionDocument): Promise<void> {
  const expiration = Math.floor(new Date(doc.expiresAt).getTime() / 1000);
  await env.SESSIONS.put(kvKey(doc.id), JSON.stringify(doc), { expiration });
}

/** Stores the bytes in R2 and appends a tagged `photo` source to the document. */
export async function addPhotoSource(
  env: Env,
  doc: SessionDocument,
  bytes: ArrayBuffer,
  mediaType: string
): Promise<PhotoSource> {
  const source: PhotoSource = {
    kind: "photo",
    id: crypto.randomUUID(),
    mediaType,
    bytes: bytes.byteLength,
    addedAt: new Date().toISOString(),
  };
  if (!env.SOURCES) throw new Error("SOURCES binding is not configured");
  await env.SOURCES.put(r2Key(doc.id, source.id), bytes, {
    httpMetadata: { contentType: mediaType },
  });
  doc.sources.push(source);
  await saveSession(env, doc);
  return source;
}

export async function getSourceObject(env: Env, sessionId: string, sourceId: string): Promise<R2ObjectBody | null> {
  if (!env.SOURCES) return null;
  return env.SOURCES.get(r2Key(sessionId, sourceId));
}

export function hasSourceStorage(env: Env): boolean {
  return env.SOURCES !== undefined;
}
