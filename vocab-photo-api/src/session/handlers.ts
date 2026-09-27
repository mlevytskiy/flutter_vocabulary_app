import { MAX_RAW_BYTES, htmlResponse, isAllowedMediaType, jsonResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
import { ankiFileName, renderAnkiFileFor } from "./anki";
import { renderNotFoundPage, renderSessionPage } from "./page";
import {
  createSession,
  getSourceObject,
  hasSourceStorage,
  loadSession,
  republishSession,
  storeDeclaredPhoto,
} from "./store";
import {
  ID_PATTERN,
  MAX_SESSION_JSON_BYTES,
  parseDetail,
  parseEntries,
  parseRepublish,
  parseSources,
  toDocument,
} from "./types";

function publicUrl(url: URL, sessionId: string): string {
  return `${url.origin}/s/${sessionId}`;
}

/**
 * POST /sessions -- secret-gated.
 * `{ detail?, entries: [{word, translation, definition?, sourceId?}], sources?: [{id, order}],
 *    publishedId?, editToken? }` -> `{ id, url, expiresAt, editToken }`.
 * With a `publishedId` and the `editToken` it was published with, the same
 * link is overwritten (ADR-0008); an expired id or a wrong token publishes a
 * new link instead, so the app always gets a working one back.
 */
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
  const record = body as Record<string, unknown>;
  const sources = parseSources(record.sources);
  if (!sources.ok) {
    return jsonResponse({ error: sources.error }, 400);
  }
  const parsed = parseEntries(record.entries, new Set(sources.sources.map((source) => source.id)));
  if (!parsed.ok) {
    return jsonResponse({ error: parsed.error }, 400);
  }
  const detail = parseDetail(record.detail);
  if (!detail.ok) {
    return jsonResponse({ error: detail.error }, 400);
  }
  const republish = parseRepublish(record);
  if (!republish.ok) {
    return jsonResponse({ error: republish.error }, 400);
  }

  const input = { entries: parsed.entries, sources: sources.sources, detail: detail.detail };
  const published =
    (republish.republish &&
      (await republishSession(env, republish.republish.publishedId, republish.republish.editToken, input))) ||
    (await createSession(env, input));
  const { session, editToken } = published;
  return jsonResponse({ id: session.id, url: publicUrl(url, session.id), expiresAt: session.expiresAt, editToken });
}

/**
 * POST /sessions/:id/sources/:sourceId -- secret-gated. Raw image bytes, like
 * /analyze, for a photo the publish declared (ADR-0006). A repeat after the
 * bytes arrived answers the same and changes nothing, so the app may retry.
 */
async function handleUploadSource({ request, env, url, params }: RouteContext): Promise<Response> {
  if (!hasSourceStorage(env)) {
    return jsonResponse({ error: "Source storage is not configured on this Worker (enable R2, see README)" }, 503);
  }
  const mediaType = request.headers.get("content-type");
  if (!isAllowedMediaType(mediaType)) {
    return jsonResponse({ error: "Content-Type header must be one of: image/jpeg, image/png, image/webp" }, 400);
  }
  const session = await loadSession(env, params.id);
  if (!session) {
    return jsonResponse({ error: "Session not found" }, 404);
  }
  if (!session.sources.some((source) => source.id === params.sourceId)) {
    return jsonResponse({ error: "This session declared no source with that id" }, 404);
  }

  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0) {
    return jsonResponse({ error: "Request body must contain image bytes" }, 400);
  }
  if (bytes.byteLength > MAX_RAW_BYTES) {
    return jsonResponse({ error: "Image is too large" }, 413);
  }

  const outcome = await storeDeclaredPhoto(env, session, params.sourceId, bytes, mediaType);
  if (outcome === "not_declared") {
    return jsonResponse({ error: "This session declared no source with that id" }, 404);
  }
  return jsonResponse({
    sourceId: params.sourceId,
    url: `${publicUrl(url, session.id)}/sources/${params.sourceId}`,
    pageUrl: publicUrl(url, session.id),
  });
}

/** GET /s/:id -- public. The page a person reads. */
async function handleSessionPage({ env, params }: RouteContext): Promise<Response> {
  const session = await loadSession(env, params.id);
  if (!session) {
    return htmlResponse(renderNotFoundPage(), 404);
  }
  return htmlResponse(renderSessionPage(toDocument(session)));
}

/**
 * GET /s/:id/words.txt -- public. The AnkiDroid file, generated from the
 * stored session at request time so it always reflects the current words
 * (task-07). Served as a download: without `content-disposition: attachment`
 * a phone browser renders the text inline and there is no file to hand to
 * AnkiDroid.
 */
async function handleAnkiDownload({ env, params }: RouteContext): Promise<Response> {
  const session = await loadSession(env, params.id);
  if (!session) {
    return htmlResponse(renderNotFoundPage(), 404);
  }
  return new Response(renderAnkiFileFor(toDocument(session)), {
    status: 200,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "content-disposition": `attachment; filename="${ankiFileName(new Date())}"`,
      "cache-control": "no-store",
    },
  });
}

/**
 * GET /s/:id/sources/:sourceId -- public. The bytes of one arrived photo of this
 * session, served as the page's <img>. Anything else is the gone page (AC-24).
 */
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
    pattern: new RegExp(`^/sessions/(?<id>${ID_PATTERN})/sources/(?<sourceId>${ID_PATTERN})$`),
    public: false,
    handler: handleUploadSource,
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
