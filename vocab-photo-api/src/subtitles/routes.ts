import type { Env } from "../env";
import { jsonResponse } from "../http";
import { logEvent } from "../log";
import type { RouteContext, RouteDefinition } from "../routing";
import { takeSubtitleImport } from "./allowance";
import {
  ENGLISH_LEVELS,
  IMPORT_PURPOSES,
  buildSubtitleRequest,
  isSubtitleModel,
  parseSubtitleReply,
  type EnglishLevel,
  type ImportPurpose,
  type SubtitleModel,
  type SubtitleWord,
} from "./prompt";

// POST /subtitles/words (words-from-subtitles, docs/features/words-from-subtitles/
// contracts/openapi.yaml). The app strips a subtitle file to its dialogue lines
// (ADR-0002) and sends them here; the Worker checks the bounds and the model
// allow-list, takes one import from the allowance (ADR-0003), asks the chosen
// model once, and returns at most `maximum` words or an error -- never a partial
// list. Secret-gated and rate-limited by the `fetch` handler like every
// non-public route (AC-13).

const DEFAULT_API_URL = "https://api.anthropic.com/";
/** The app gives up at 240 s; answering by 225 s lets it show the Worker's message instead. */
const AI_TIMEOUT_MS = 225_000;
const MAX_LINE_CHARS = 200;
/** 1 MB of dialogue lines, the same 1 MB as the largest file the app accepts (AC-11). */
const MAX_LINES_BYTES = 1_048_576;
/** The whole body: the lines, up to 500 session words of up to 500 characters, and JSON overhead. */
const MAX_BODY_BYTES = 2 * 1_048_576;
const MAX_SESSION_WORDS = 500;
const MAX_SESSION_WORD_CHARS = 500;

type ErrorCode = "bad_request" | "unknown_model" | "too_large" | "no_english_lines" | "too_many_imports" | "words_not_picked";

const fail = (status: number, code: ErrorCode, error: string) => jsonResponse({ error, code }, status);

interface SubtitleWordsRequest {
  lines: string[];
  purpose: ImportPurpose;
  level: EnglishLevel;
  maximum: number;
  model: SubtitleModel;
  sessionWords: string[];
}

const isStringArray = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((item) => typeof item === "string");

/** The request, or the error response for the first bound it breaks. */
function readRequest(text: string): SubtitleWordsRequest | Response {
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return fail(400, "bad_request", "Body must be JSON");
  }
  if (typeof body !== "object" || body === null) return fail(400, "bad_request", "Body must be a JSON object");
  const { lines, purpose, level, maximum, model, sessionWords } = body as Record<string, unknown>;

  if (!isStringArray(lines) || lines.length === 0) {
    return fail(400, "bad_request", "lines must be a non-empty array of strings");
  }
  if (lines.some((line) => line.length === 0 || line.length > MAX_LINE_CHARS)) {
    return fail(400, "bad_request", `Each line must hold 1 to ${MAX_LINE_CHARS} characters`);
  }
  if (typeof purpose !== "string" || !(IMPORT_PURPOSES as readonly string[]).includes(purpose)) {
    return fail(400, "bad_request", `purpose must be one of: ${IMPORT_PURPOSES.join(", ")}`);
  }
  if (typeof level !== "string" || !(ENGLISH_LEVELS as readonly string[]).includes(level)) {
    return fail(400, "bad_request", `level must be one of: ${ENGLISH_LEVELS.join(", ")}`);
  }
  if (typeof maximum !== "number" || !Number.isInteger(maximum) || maximum < 1 || maximum > 100) {
    return fail(400, "bad_request", "maximum must be a whole number from 1 to 100");
  }
  if (
    !isStringArray(sessionWords) ||
    sessionWords.length > MAX_SESSION_WORDS ||
    sessionWords.some((word) => word.length > MAX_SESSION_WORD_CHARS)
  ) {
    return fail(
      400,
      "bad_request",
      `sessionWords must be at most ${MAX_SESSION_WORDS} strings of at most ${MAX_SESSION_WORD_CHARS} characters`
    );
  }
  if (typeof model !== "string") return fail(400, "bad_request", "model must be a string");

  const encoder = new TextEncoder();
  const linesBytes = lines.reduce((sum, line) => sum + encoder.encode(line).length, 0);
  if (linesBytes > MAX_LINES_BYTES) return fail(413, "too_large", "The subtitle lines are too large");

  if (!isSubtitleModel(model)) return fail(400, "unknown_model", "This model is not offered for subtitle imports");

  return {
    lines,
    purpose: purpose as ImportPurpose,
    level: level as EnglishLevel,
    maximum,
    model,
    sessionWords,
  };
}

/**
 * The model's ranked candidates without the session's words (any letter case,
 * AC-15) and without repeats, cut to the maximum in rank order (AC-06, AC-19).
 */
export function keepWords(candidates: SubtitleWord[], sessionWords: string[], maximum: number): SubtitleWord[] {
  const seen = new Set(sessionWords.map((word) => word.trim().toLowerCase()));
  const kept: SubtitleWord[] = [];
  for (const candidate of candidates) {
    const key = candidate.word.trim().toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    kept.push(candidate);
    if (kept.length === maximum) break;
  }
  return kept;
}

async function callModel(env: Env, req: SubtitleWordsRequest): Promise<{ reply: ReturnType<typeof parseSubtitleReply>; aiMs: number }> {
  const timeoutMs = Number(env.SUBTITLE_AI_TIMEOUT_MS) || AI_TIMEOUT_MS;
  const startedAt = Date.now();
  const response = await fetch(new URL("v1/messages", env.ANTHROPIC_API_URL || DEFAULT_API_URL), {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(buildSubtitleRequest(req)),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`Anthropic API error (${response.status}): ${detail.slice(0, 300)}`);
  }
  const reply = parseSubtitleReply(await response.json());
  return { reply, aiMs: Date.now() - startedAt };
}

async function handleSubtitleWords({ request, env }: RouteContext): Promise<Response> {
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) {
    return fail(413, "too_large", "The subtitle lines are too large");
  }
  const req = readRequest(text);
  if (req instanceof Response) return req;

  const address = request.headers.get("cf-connecting-ip") ?? "unknown";
  const take = await takeSubtitleImport(env, address);
  if (take.outcome === "refused") {
    logEvent("subtitle import refused", { model: req.model, reason: take.reason });
    return fail(429, "too_many_imports", "Too many subtitle imports. Wait a few minutes and try again.");
  }

  let result: Awaited<ReturnType<typeof callModel>>;
  try {
    result = await callModel(env, req);
  } catch (err) {
    // Log the reason only -- never the lines or the session words (sad §8 Logging).
    logEvent("subtitle import failed", { model: req.model, reason: err instanceof Error ? err.name + ": " + err.message.slice(0, 200) : "unknown" });
    return fail(502, "words_not_picked", "The words could not be picked, please try again");
  }

  const { reply, aiMs } = result;
  if (reply.kind === "no_english") {
    logEvent("subtitle import", { model: req.model, outcome: "no_english", aiMs, ...tokens(reply.usage) });
    return fail(422, "no_english_lines", "No English subtitles to read in this file");
  }
  const words = keepWords(reply.words, req.sessionWords, req.maximum);
  logEvent("subtitle import", { model: req.model, outcome: "words", aiMs, words: words.length, ...tokens(reply.usage) });
  return jsonResponse({ words, model: req.model, timings: { aiMs }, usage: reply.usage });
}

const tokens = (usage: { inputTokens: number; outputTokens: number }) => ({
  inputTokens: usage.inputTokens,
  outputTokens: usage.outputTokens,
});

export const subtitleRoutes: RouteDefinition[] = [
  { method: "POST", pattern: /^\/subtitles\/words$/, public: false, handler: handleSubtitleWords },
];
