import { MAX_RAW_BYTES, htmlResponse, isAllowedMediaType, jsonResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
import { ankiFileName, renderAnkiFileFor } from "./anki";
import { renderNotFoundPage, renderSessionPage } from "./page";
import { addPhotoSource, createSession, getSession, getSourceObject, hasSourceStorage } from "./store";
import { MAX_SESSION_JSON_BYTES, MAX_SOURCES, parseEntries } from "./types";

const ID_PATTERN = "[A-Za-z0-9-]{1,64}";

function publicUrl(url: URL, sessionId: string): string {
  return `${url.origin}/s/${sessionId}`;
}

/** POST /sessions -- secret-gated. `{ entries: [{word, translation}] }` -> `{ id, url, expiresAt }`. */
async function handleCreateSession({ request, env, url }: RouteContext): Promise<Response> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > MAX_SESSION_JSON_BYTES) {
    return jsonResponse({ error: "Payload is too large" }, 413);
  }
  const text = await request.text();
  if (text.length > MAX_SESSION_JSON_BYTES) {
    return jsonResponse({ error: "Payload is too large" }, 413);
  }

  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  if (typeof body !== "object" || body === null) {
    return jsonResponse({ error: "Body must be a JSON object with an `entries` array" }, 400);
  }
  const parsed = parseEntries((body as Record<string, unknown>).entries);
  if (!parsed.ok) {
    return jsonResponse({ error: parsed.error }, 400);
  }

  const doc = await createSession(env, parsed.entries);
  return jsonResponse({ id: doc.id, url: publicUrl(url, doc.id), expiresAt: doc.expiresAt });
}

/** POST /sessions/:id/sources -- secret-gated. Raw image bytes, like /analyze. */
async function handleAddSource({ request, env, url, params }: RouteContext): Promise<Response> {
  if (!hasSourceStorage(env)) {
    return jsonResponse({ error: "Source storage is not configured on this Worker (enable R2, see README)" }, 503);
  }
  const mediaType = request.headers.get("content-type");
  if (!isAllowedMediaType(mediaType)) {
    return jsonResponse({ error: "Content-Type header must be one of: image/jpeg, image/png, image/webp" }, 400);
  }
  const doc = await getSession(env, params.id);
  if (!doc) {
    return jsonResponse({ error: "Session not found" }, 404);
  }
  if (doc.sources.length >= MAX_SOURCES) {
    return jsonResponse({ error: `A session holds at most ${MAX_SOURCES} sources` }, 400);
  }

  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0) {
    return jsonResponse({ error: "Request body must contain image bytes" }, 400);
  }
  if (bytes.byteLength > MAX_RAW_BYTES) {
    return jsonResponse({ error: "Image is too large" }, 413);
  }

  const source = await addPhotoSource(env, doc, bytes, mediaType);
  return jsonResponse({
    sourceId: source.id,
    url: `${publicUrl(url, doc.id)}/sources/${source.id}`,
    pageUrl: publicUrl(url, doc.id),
  });
}

/** GET /s/:id -- public. The page a person reads. */
async function handleSessionPage({ env, params }: RouteContext): Promise<Response> {
  const doc = await getSession(env, params.id);
  if (!doc) {
    return htmlResponse(renderNotFoundPage(), 404);
  }
  return htmlResponse(renderSessionPage(doc));
}

/**
 * GET /s/:id/words.txt -- public. The AnkiDroid file, generated from the
 * stored session at request time so it always reflects the current words
 * (task-07). Served as a download: without `content-disposition: attachment`
 * a phone browser renders the text inline and there is no file to hand to
 * AnkiDroid.
 */
async function handleAnkiDownload({ env, params }: RouteContext): Promise<Response> {
  const doc = await getSession(env, params.id);
  if (!doc) {
    return htmlResponse(renderNotFoundPage(), 404);
  }
  return new Response(renderAnkiFileFor(doc), {
    status: 200,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "content-disposition": `attachment; filename="${ankiFileName(new Date())}"`,
      "cache-control": "no-store",
    },
  });
}

/** GET /s/:id/sources/:sourceId -- public. The bytes of one source, served as the page's <img>. */
async function handleGetSource({ env, params }: RouteContext): Promise<Response> {
  const object = await getSourceObject(env, params.id, params.sourceId);
  if (!object) {
    return htmlResponse(renderNotFoundPage(), 404);
  }
  return new Response(object.body, {
    status: 200,
    headers: {
      "content-type": object.httpMetadata?.contentType ?? "application/octet-stream",
      "content-length": String(object.size),
      "etag": object.httpEtag,
      // A source never changes once uploaded; the id is random.
      "cache-control": "public, max-age=86400, immutable",
    },
  });
}

export const sessionRoutes: RouteDefinition[] = [
  { method: "POST", pattern: /^\/sessions$/, public: false, handler: handleCreateSession },
  {
    method: "POST",
    pattern: new RegExp(`^/sessions/(?<id>${ID_PATTERN})/sources$`),
    public: false,
    handler: handleAddSource,
  },
  { method: "GET", pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})$`), public: true, handler: handleSessionPage },
  {
    method: "GET",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/words\\.txt$`),
    public: true,
    handler: handleAnkiDownload,
  },
  {
    method: "GET",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/sources/(?<sourceId>${ID_PATTERN})$`),
    public: true,
    handler: handleGetSource,
  },
];
