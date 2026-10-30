import type { Env } from "./env";
import { CORS_HEADERS, MAX_RAW_BYTES, isAllowedMediaType, jsonResponse, type AllowedMediaType } from "./http";
import { matchRoute, type RouteContext, type RouteDefinition } from "./routing";
import { sessionRoutes } from "./session/handlers";
import { editRoutes } from "./session/edit";
import { changesRoutes } from "./session/changes";
import { autofillRoutes } from "./autofill/routes";
import { logEvent } from "./log";
import {
  buildSystemPrompt,
  parseAnalyzeAnswer,
  parseOptions,
  type AnalyzeAnswer,
  type Options,
} from "./analyze.ts";
import { defineRoutes } from "./define";
import { deleteExpiredSessions } from "./session/cleanup";
import { assetRoutes } from "./session/assets";
import { learnRoutes } from "./learn/routes";
import { subtitleRoutes } from "./subtitles/routes";
import { subtitleSearchRoutes } from "./subtitles/search";
import { storyRoutes } from "./story/routes.ts";
import { namingRoutes } from "./naming/routes.ts";
import { deleteOldPictures } from "./story/store.ts";

export type { Env } from "./env";
export { StoryRunWorkflow } from "./story/workflow.ts";

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunkSize = 0x8000; // process in chunks to avoid call-stack limits on large buffers
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

interface ClaudeResult extends AnalyzeAnswer {
  aiMs: number;
}

async function callClaude(
  env: Env,
  imageBase64: string,
  mediaType: AllowedMediaType,
  options: Options
): Promise<ClaudeResult> {
  const startedAt = Date.now();
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-sonnet-5",
      // With `context=true` the answer also carries the photo's full text (word-context AC-10).
      max_tokens: options.context ? 4096 : 1536,
      // The system prompt only depends on `options`, which the app always sends the
      // same way, so it's identical across requests. Caching it shaves the fixed
      // system-prompt tokens off both latency and cost on every call after the first
      // within the 5-minute cache window.
      system: [
        {
          type: "text",
          text: buildSystemPrompt(options),
          cache_control: { type: "ephemeral" },
        },
      ],
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: imageBase64 } },
            { type: "text", text: "Extract the vocabulary words from this photo." },
          ],
        },
      ],
    }),
  });
  const aiMs = Date.now() - startedAt;

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`Anthropic API error (${response.status}): ${detail.slice(0, 500)}`);
  }

  const data = (await response.json()) as {
    content?: Array<{ type: string; text?: string }>;
    usage?: { cache_read_input_tokens?: number; cache_creation_input_tokens?: number };
  };

  console.log(
    `claude call took ${aiMs}ms (cache_read=${data.usage?.cache_read_input_tokens ?? 0} tokens, ` +
      `cache_write=${data.usage?.cache_creation_input_tokens ?? 0} tokens)`
  );

  const textBlock = data.content?.find((block) => block.type === "text" && typeof block.text === "string");
  if (!textBlock?.text) {
    throw new Error("Anthropic response contained no text content");
  }

  let answer: AnalyzeAnswer | null;
  try {
    answer = parseAnalyzeAnswer(textBlock.text, options);
  } catch {
    throw new Error("Failed to parse JSON from Anthropic response");
  }

  if (!answer) {
    throw new Error("Anthropic response JSON did not match the expected shape");
  }

  return { ...answer, aiMs };
}

async function handleAnalyze({ request, env, url }: RouteContext): Promise<Response> {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed, use POST" }, 405);
  }

  const mediaType = request.headers.get("content-type");
  if (!isAllowedMediaType(mediaType)) {
    return jsonResponse({ error: "Content-Type header must be one of: image/jpeg, image/png, image/webp" }, 400);
  }

  const imageBytes = await request.arrayBuffer();
  if (imageBytes.byteLength === 0) {
    return jsonResponse({ error: "Request body must contain image bytes" }, 400);
  }
  if (imageBytes.byteLength > MAX_RAW_BYTES) {
    return jsonResponse({ error: "Image is too large" }, 413);
  }

  const options = parseOptions(url);
  if (!options.context && !options.translation && !options.withDesc) {
    options.translation = true;
  }

  try {
    const imageBase64 = arrayBufferToBase64(imageBytes);
    const { words, full_text, aiMs } = await callClaude(env, imageBase64, mediaType, options);
    // Cheap backstop against a runaway response, not the mechanism: the prompt is
    // what keeps the list to the marked words, and this keeps the first N in the
    // order the model returned them (reading order, per D2).
    const limited = options.limit !== undefined ? words.slice(0, options.limit) : words;
    // `full_text` only with `context=true` (word-context AC-10); without it the answer is as before.
    return jsonResponse({ words: limited, ...(full_text !== undefined ? { full_text } : {}), timings: { aiMs } });
  } catch (err) {
    console.error("analyze failed", err);
    return jsonResponse({ error: "Failed to analyze photo, please try again" }, 502);
  }
}

// Every route declares whether it is public. Anything not marked `public: true`
// -- /analyze, /define, /subtitles/words and the session writes -- is behind the shared secret and the
// per-IP rate limiter. The shared page, its sources and its script are public by
// definition: the link is the only credential (docs/idea-brief.md §5). The
// page's own writes are public too, and those marked `pageWrite` share the
// per-IP page write limit instead (sad §8).
const ROUTES: RouteDefinition[] = [
  { method: "POST", pattern: /^\/analyze$/, public: false, handler: handleAnalyze },
  ...defineRoutes,
  ...sessionRoutes,
  ...editRoutes,
  ...changesRoutes,
  ...autofillRoutes,
  ...assetRoutes,
  ...subtitleRoutes,
  ...subtitleSearchRoutes,
  ...learnRoutes,
  ...storyRoutes,
  ...namingRoutes,
];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const match = matchRoute(ROUTES, request.method, url.pathname);
    if (!match) {
      return jsonResponse({ error: "Not found" }, 404);
    }
    if ("methodNotAllowed" in match) {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }
    const { route, params } = match;

    if (!route.public) {
      const providedSecret = request.headers.get("x-app-secret");
      if (!env.APP_SHARED_SECRET || providedSecret !== env.APP_SHARED_SECRET) {
        return jsonResponse({ error: "Unauthorized" }, 401);
      }

      const clientIp = request.headers.get("cf-connecting-ip") ?? "unknown";
      const { success: withinRateLimit } = await env.RATE_LIMITER.limit({ key: clientIp });
      if (!withinRateLimit) {
        return jsonResponse({ error: "Too many requests, please slow down" }, 429);
      }
    } else if (route.pageWrite) {
      const clientIp = request.headers.get("cf-connecting-ip") ?? "unknown";
      const { success: withinPageLimit } = await env.PAGE_WRITE_LIMITER.limit({ key: `page:${clientIp}` });
      if (!withinPageLimit) {
        logEvent("page write limited", { route: url.pathname.split("/").pop() ?? "" });
        return jsonResponse(
          { error: "Too many changes at once. Wait a moment and try again.", code: "rate_limited" },
          429
        );
      }
    }

    return route.handler({ request, env, url, params });
  },

  // The daily clean-up, `triggers.crons` in wrangler.jsonc (sad §7).
  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    // Both clean-ups run even if one fails; a failure is still reported.
    const results = await Promise.allSettled([deleteExpiredSessions(env), deleteOldPictures(env)]);
    for (const result of results) if (result.status === "rejected") throw result.reason;
  },
};
