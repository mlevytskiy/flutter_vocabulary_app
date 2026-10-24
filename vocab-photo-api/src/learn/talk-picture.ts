// POST /learn/talk/picture -- the opening picture of a Talk mission (talk-mission, owner 2026-10-24).
// The app asks for it with the mission's picture prompt right after the opening line, so the talk never
// waits for it. One cheap picture call; each takes one unit of the 20-a-day allowance before the call.
// The prompt is never logged.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { CORS_HEADERS, jsonResponse } from "../http.ts";
import { logEvent } from "../log.ts";
import type { RouteContext, RouteDefinition } from "../routing";
import { drawPicture } from "../story/providers/picture.ts";
import { takeLearnTalkPicture } from "./allowance.ts";

const MAX_PROMPT_LENGTH = 600;
/** The cheapest offered picture model, 16:9 (models.json). */
export const TALK_PICTURE_MODEL = "grok-imagine-image";
/** The app gives up at 45 s, so the Worker's 40 s wins. */
const TALK_PICTURE_TIMEOUT_MS = 40_000;
export const TALK_PICTURE_STYLE =
  "A warm, friendly flat illustration with soft colours and simple shapes, like a picture book; no text, letters or signs with writing. Scene: ";

/** The picture prompt, or the reason it is not one: 1 to 600 characters. */
export function parseTalkPictureRequest(body: unknown): { prompt: string; error?: undefined } | { error: string } {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { error: "Body must be a JSON object" };
  const { prompt } = body as Record<string, unknown>;
  if (typeof prompt !== "string" || prompt.trim() === "" || prompt.length > MAX_PROMPT_LENGTH) {
    return { error: `The prompt is 1 to ${MAX_PROMPT_LENGTH} characters` };
  }
  return { prompt: prompt.trim() };
}

async function handleTalkPicture({ request, env }: RouteContext): Promise<Response> {
  const started = Date.now();
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON", code: "bad_request" }, 400);
  }
  const parsed = parseTalkPictureRequest(body);
  if (parsed.error !== undefined) return jsonResponse({ error: parsed.error, code: "bad_request" }, 400);
  // Never the prompt.
  const log = (outcome: string) => logEvent("learn talk picture", { outcome, ms: Date.now() - started });

  // One unit per picture, taken before the call and never given back.
  if (!(await takeLearnTalkPicture(env))) {
    log("day_limit");
    return jsonResponse({ error: "Today's picture limit is reached.", code: "day_limit" }, 429);
  }
  const result = await drawPicture(env, {
    model: TALK_PICTURE_MODEL,
    prompt: TALK_PICTURE_STYLE + parsed.prompt,
    timeoutMs: Number(env.LEARN_PICTURE_TIMEOUT_MS) || TALK_PICTURE_TIMEOUT_MS,
  });
  if (result.failed !== undefined) {
    log(result.failed);
    return jsonResponse({ error: "Could not draw the picture", code: "picture_failed" }, 502);
  }
  log("ok");
  return new Response(result.bytes, {
    status: 200,
    headers: { "content-type": result.contentType, "cache-control": "no-store", ...CORS_HEADERS },
  });
}

export const learnTalkPictureRoute: RouteDefinition = {
  method: "POST",
  pattern: /^\/learn\/talk\/picture$/,
  public: false,
  handler: handleTalkPicture,
};
