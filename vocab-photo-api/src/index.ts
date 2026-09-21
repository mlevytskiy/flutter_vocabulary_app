import type { Env } from "./env";
import { CORS_HEADERS, MAX_RAW_BYTES, isAllowedMediaType, jsonResponse, type AllowedMediaType } from "./http";
import { matchRoute, type RouteContext, type RouteDefinition } from "./routing";
import { sessionRoutes } from "./session/handlers";

export type { Env } from "./env";

interface Options {
  context: boolean;
  translation: boolean;
  withDesc: boolean;
  shortifyDefinition: boolean;
  limit?: number;
}

interface VocabularyWord {
  word: string;
  context?: string;
  translation?: string;
  description?: string;
}

function parseOptions(url: URL): Options {
  const limitParam = url.searchParams.get("limit");
  const limitNum = limitParam !== null ? Number(limitParam) : undefined;
  const limit = limitNum !== undefined && Number.isInteger(limitNum) && limitNum > 0 ? limitNum : undefined;

  return {
    context: url.searchParams.get("context") === "true",
    translation: url.searchParams.get("translation") === "true",
    withDesc: url.searchParams.get("with_desc") === "true",
    shortifyDefinition: url.searchParams.get("shortify_definishion") === "true",
    limit,
  };
}

function buildSystemPrompt(options: Options): string {
  const fields = ['"word": "<original English word or phrase>"'];
  const instructions: string[] = [];

  if (options.context) {
    fields.push('"context": "<the exact sentence or phrase from the photo where this word appears>"');
    instructions.push("- context: quote the exact sentence or phrase the word appears in within the photo.");
  }
  const shortifyLine = options.shortifyDefinition
    ? " If it is long, shorten it as much as possible without losing its meaning."
    : "";

  if (options.translation) {
    fields.push('"translation": "<Ukrainian translation of the word, fitting its meaning in this context>"');
    instructions.push(
      "- translation: if the photo itself already shows a Ukrainian translation for this word (e.g. a glossary, " +
        "subtitle, or bilingual label), use that exact translation instead of producing your own. Otherwise, " +
        `translate the word to Ukrainian yourself, choosing the sense that fits how it is used in the photo.${shortifyLine}`
    );
  }
  if (options.withDesc) {
    fields.push('"description": "<short English definition of the word, fitting its meaning in this context>"');
    instructions.push(
      "- description: if the photo itself already shows a definition for this word (e.g. a glossary or dictionary " +
        "entry), use that definition, condensed to one sentence if it is longer. Otherwise, write a short (one " +
        `sentence) English definition yourself, matching the meaning the word has in this context.${shortifyLine}`
    );
  }

  // D2 (docs/roadmap.md): over the limit we keep the first N in reading order and
  // drop the rest. No "most useful for a learner" ranking -- that is a judgement the
  // owner can neither see nor predict, and the marks already say what they wanted.
  const limitLine = options.limit
    ? `Return at most ${options.limit} marked words or phrases in total. If the photo has fewer than ` +
      `${options.limit} marked words, return only the ones that are actually marked — never pad or invent ` +
      `extra entries to reach the limit. If more than ${options.limit} words are marked, keep the first ` +
      `${options.limit} in reading order (top to bottom, then left to right) and drop the rest — do not ` +
      `rank them by how useful or valuable they look.`
    : "Return every marked word or phrase you find, in reading order (top to bottom, then left to right).";

  return `You are a vocabulary-extraction assistant for a language learner \
whose native language is Ukrainian and who is learning English.

You will be given a photo of something the learner has been reading — a book page, packaging, a \
sign, or a screen — on which they have visually marked the words they want to learn.

Return ONLY the English words or short phrases that the photo shows as visually marked: \
highlighter, underline, circle, box, pen or pencil stroke, an arrow pointing at the word, or any \
other hand-made mark on or around the word. A word counts as marked only if you can actually see \
its mark in the photo.

Do NOT return a word that carries no mark, however useful it looks. A dense page of valuable \
vocabulary with nothing marked on it yields an empty array — that is the correct answer, not a \
failure. Never fill the response with unmarked words.

Ignore noise, even when it is marked: numbers, single letters, barcodes, UI chrome, and words that \
are not meaningful vocabulary. Ignore marked text that is not English (Ukrainian words, for \
example) — this learner is collecting English vocabulary, so do not translate or guess at it.

${limitLine}

Prefer information that is already visible in the photo (existing translations, definitions, or glossary \
entries) over inventing your own — only generate a translation or definition yourself when the photo doesn't \
already provide one.

For each selected word or phrase, include:
${instructions.join("\n")}

Respond with ONLY a strict JSON array, no prose, no markdown code fences, in this exact shape:
[{${fields.join(", ")}}]

If the photo has no marked English vocabulary — including a photo full of unmarked useful words — \
respond with an empty array: []`;
}

function extractJsonArray(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  const candidate = fenced ? fenced[1] : trimmed;
  return JSON.parse(candidate);
}

function isVocabularyWordArray(value: unknown, options: Options): value is VocabularyWord[] {
  return (
    Array.isArray(value) &&
    value.every((item) => {
      if (typeof item !== "object" || item === null) return false;
      const record = item as Record<string, unknown>;
      if (typeof record.word !== "string") return false;
      if (options.context && typeof record.context !== "string") return false;
      if (options.translation && typeof record.translation !== "string") return false;
      if (options.withDesc && typeof record.description !== "string") return false;
      return true;
    })
  );
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunkSize = 0x8000; // process in chunks to avoid call-stack limits on large buffers
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

interface ClaudeResult {
  words: VocabularyWord[];
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
      max_tokens: 1536,
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
            { type: "text", text: "Extract the marked vocabulary words from this photo." },
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

  let parsed: unknown;
  try {
    parsed = extractJsonArray(textBlock.text);
  } catch {
    throw new Error("Failed to parse JSON from Anthropic response");
  }

  if (!isVocabularyWordArray(parsed, options)) {
    throw new Error("Anthropic response JSON did not match the expected shape");
  }

  return { words: parsed, aiMs };
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
    const { words, aiMs } = await callClaude(env, imageBase64, mediaType, options);
    // Cheap backstop against a runaway response, not the mechanism: the prompt is
    // what keeps the list to the marked words, and this keeps the first N in the
    // order the model returned them (reading order, per D2).
    const limited = options.limit !== undefined ? words.slice(0, options.limit) : words;
    return jsonResponse({ words: limited, timings: { aiMs } });
  } catch (err) {
    console.error("analyze failed", err);
    return jsonResponse({ error: "Failed to analyze photo, please try again" }, 502);
  }
}

// Every route declares whether it is public. Anything not marked `public: true`
// -- /analyze, and the session writes -- is behind the shared secret and the
// per-IP rate limiter. The shared page and its sources are public by
// definition: the link is the only credential (docs/idea-brief.md §5).
const ROUTES: RouteDefinition[] = [
  { method: "POST", pattern: /^\/analyze$/, public: false, handler: handleAnalyze },
  ...sessionRoutes,
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
    }

    return route.handler({ request, env, url, params });
  },
};
