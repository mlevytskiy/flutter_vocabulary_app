// POST /collections/name, /collections/description and /collections/autofill (many at once), behind the app secret (collection-naming, owner 2026-10-18).

import { jsonResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
import { autofillCollections, describeCollection, nameCollection, parseBatchRequest, parseNamingRequest } from "./name.ts";

async function handleName({ request, env }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  const parsed = parseNamingRequest(body);
  if ("error" in parsed) return jsonResponse(parsed, parsed.code === "not_offered" ? 422 : 400);
  const name = await nameCollection(env, parsed);
  if (!name) return jsonResponse({ error: "Could not name the collection", code: "naming_failed" }, 502);
  return jsonResponse({ name, model: parsed.model });
}

async function handleDescription({ request, env }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  const parsed = parseNamingRequest(body);
  if ("error" in parsed) return jsonResponse(parsed, parsed.code === "not_offered" ? 422 : 400);
  const description = await describeCollection(env, parsed);
  if (!description) return jsonResponse({ error: "Could not describe the collection", code: "description_failed" }, 502);
  return jsonResponse({ description, model: parsed.model });
}

/** One AI call for many collections: the app's upgrade of collections from before collection-naming. */
async function handleAutofill({ request, env }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  const parsed = parseBatchRequest(body);
  if ("error" in parsed) return jsonResponse(parsed, parsed.code === "not_offered" ? 422 : 400);
  const collections = await autofillCollections(env, parsed);
  if (!collections) return jsonResponse({ error: "Could not name the collections", code: "autofill_failed" }, 502);
  return jsonResponse({ collections, model: parsed.model });
}

export const namingRoutes: RouteDefinition[] = [
  { method: "POST", pattern: /^\/collections\/name$/, public: false, handler: handleName },
  { method: "POST", pattern: /^\/collections\/description$/, public: false, handler: handleDescription },
  { method: "POST", pattern: /^\/collections\/autofill$/, public: false, handler: handleAutofill },
];
