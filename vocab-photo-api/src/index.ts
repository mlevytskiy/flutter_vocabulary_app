import { fetchReversoContext, fetchReversoTranslation } from "./reverso";

export interface Env {
  ANTHROPIC_API_KEY: string;
  APP_SHARED_SECRET: string;
  RATE_LIMITER: { limit: (opts: { key: string }) => Promise<{ success: boolean }> };
}

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

const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
type AllowedMediaType = (typeof ALLOWED_MEDIA_TYPES)[number];

// ~7MB raw grows to ~9.3MB once base64-encoded for Anthropic, comfortably under its 10MB limit.
const MAX_RAW_BYTES = 7 * 1024 * 1024;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, x-app-secret",
};

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

  const limitLine = options.limit
    ? `Return at most ${options.limit} words or phrases in total. If you find fewer than ${options.limit}, ` +
      `return only the ones you actually found — never pad or invent extra entries to reach the limit. ` +
      `If you find more than ${options.limit} candidates, keep only the ${options.limit} most useful/valuable ones for a learner.`
    : "Return every useful word or phrase you find.";

  return `You are a vocabulary-extraction assistant for a language learner \
whose native language is Ukrainian and who is learning English.

You will be given a photo. Find the useful English words or short phrases visible in it \
(for example on packaging, signs, book pages, or screens). Ignore noise: numbers, single \
letters, barcodes, UI chrome, and words that are not meaningful vocabulary.

${limitLine}

Prefer information that is already visible in the photo (existing translations, definitions, or glossary \
entries) over inventing your own — only generate a translation or definition yourself when the photo doesn't \
already provide one.

For each selected word or phrase, include:
${instructions.join("\n")}

Respond with ONLY a strict JSON array, no prose, no markdown code fences, in this exact shape:
[{${fields.join(", ")}}]

If no useful vocabulary is visible, respond with an empty array: []`;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...CORS_HEADERS },
  });
}

function isAllowedMediaType(value: unknown): value is AllowedMediaType {
  return typeof value === "string" && (ALLOWED_MEDIA_TYPES as readonly string[]).includes(value);
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

async function handleAnalyze(request: Request, env: Env, url: URL): Promise<Response> {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed, use POST" }, 405);
  }

  const mediaType = request.headers.get("content-type");
  if (!isAllowedMediaType(mediaType)) {
    return jsonResponse({ error: `Content-Type header must be one of: ${ALLOWED_MEDIA_TYPES.join(", ")}` }, 400);
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
    const limited = options.limit !== undefined ? words.slice(0, options.limit) : words;
    return jsonResponse({ words: limited, timings: { aiMs } });
  } catch (err) {
    console.error("analyze failed", err);
    return jsonResponse({ error: "Failed to analyze photo, please try again" }, 502);
  }
}

async function handleReversoContext(request: Request, url: URL): Promise<Response> {
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed, use GET" }, 405);
  }

  const word = url.searchParams.get("word")?.trim();
  if (!word) {
    return jsonResponse({ error: "Query param 'word' is required" }, 400);
  }
  const from = url.searchParams.get("from")?.trim() || "eng";
  const to = url.searchParams.get("to")?.trim() || "ukr";

  try {
    const result = await fetchReversoContext(word, from, to);
    return jsonResponse(result);
  } catch (err) {
    console.error("reverso context lookup failed", err);
    return jsonResponse({ error: "Reverso context lookup failed, please try again" }, 502);
  }
}

async function handleReversoTranslation(request: Request, url: URL): Promise<Response> {
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed, use GET" }, 405);
  }

  const word = url.searchParams.get("word")?.trim();
  if (!word) {
    return jsonResponse({ error: "Query param 'word' is required" }, 400);
  }
  const from = url.searchParams.get("from")?.trim() || "eng";
  const to = url.searchParams.get("to")?.trim() || "ukr";

  try {
    const result = await fetchReversoTranslation(word, from, to);
    return jsonResponse(result);
  } catch (err) {
    console.error("reverso translation lookup failed", err);
    return jsonResponse({ error: "Reverso translation lookup failed, please try again" }, 502);
  }
}

const ROUTES: Record<string, (request: Request, env: Env, url: URL) => Promise<Response>> = {
  "/analyze": (request, env, url) => handleAnalyze(request, env, url),
  "/reverso-context": (request, _env, url) => handleReversoContext(request, url),
  "/reverso-translation": (request, _env, url) => handleReversoTranslation(request, url),
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const route = ROUTES[url.pathname];
    if (!route) {
      return jsonResponse({ error: "Not found" }, 404);
    }

    const providedSecret = request.headers.get("x-app-secret");
    if (!env.APP_SHARED_SECRET || providedSecret !== env.APP_SHARED_SECRET) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const clientIp = request.headers.get("cf-connecting-ip") ?? "unknown";
    const { success: withinRateLimit } = await env.RATE_LIMITER.limit({ key: clientIp });
    if (!withinRateLimit) {
      return jsonResponse({ error: "Too many requests, please slow down" }, 429);
    }

    return route(request, env, url);
  },
};
