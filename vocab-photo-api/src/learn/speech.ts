// POST /learn/speech -- the AI's voice in Talk (learn-redesign openai-voice, spec AC-31, ADR-0009
// amendment, sad §5.2). One OpenAI gpt-4o-mini-tts call per spoken line; the mp3 streams straight
// through. Each call takes one unit of the 400-lines-a-day allowance before the OpenAI call. The text
// is never logged. Any failure here makes the app speak that line with the phone voice.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { CORS_HEADERS, jsonResponse } from "../http.ts";
import { logEvent } from "../log.ts";
import type { RouteContext, RouteDefinition } from "../routing";
import { takeLearnSpeech } from "./allowance.ts";

const MAX_TEXT_LENGTH = 1200;
const SPEECH_MODEL = "gpt-4o-mini-tts";
const OPENAI_API_URL = "https://api.openai.com/";
/** The app gives up at 20 s, so the Worker's 15 s wins. */
const SPEECH_TIMEOUT_MS = 15_000;

/** The voices gpt-4o-mini-tts speaks with; the app's default is coral (owner, 2026-10-24). */
export const SPEECH_VOICES: readonly string[] = ["alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer", "verse"];
export const DEFAULT_SPEECH_VOICE = "coral";
export const SPEECH_INSTRUCTIONS = "Speak slowly and clearly, like a friendly English teacher talking to a learner.";

export interface SpeechRequest {
  text: string;
  voice: string;
}

/** The line to speak, or the reason it is not one: 1 to 1200 characters, a known voice (or none). */
export function parseSpeechRequest(body: unknown): (SpeechRequest & { error?: undefined }) | { error: string } {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { error: "Body must be a JSON object" };
  const { text, voice } = body as Record<string, unknown>;
  if (typeof text !== "string" || text.trim() === "" || text.length > MAX_TEXT_LENGTH) {
    return { error: `The text is 1 to ${MAX_TEXT_LENGTH} characters` };
  }
  if (voice !== undefined && (typeof voice !== "string" || !SPEECH_VOICES.includes(voice))) {
    return { error: `The voice is one of ${SPEECH_VOICES.join(", ")}` };
  }
  return { text, voice: voice ?? DEFAULT_SPEECH_VOICE };
}

const badRequest = (error: string) => jsonResponse({ error, code: "bad_request" }, 400);

async function handleLearnSpeech({ request, env }: RouteContext): Promise<Response> {
  const started = Date.now();
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return badRequest("Body must be JSON");
  }
  const parsed = parseSpeechRequest(body);
  if (parsed.error !== undefined) return badRequest(parsed.error);
  // Never the text.
  const log = (outcome: string) => logEvent("learn speech", { voice: parsed.voice, chars: parsed.text.length, outcome, ms: Date.now() - started });

  const key = env.OPENAI_API_KEY;
  if (!key) {
    log("no_key");
    return jsonResponse({ error: "The AI voice is not set up", code: "speech_unavailable" }, 503);
  }
  // One unit per line, taken before the call and never given back.
  if (!(await takeLearnSpeech(env))) {
    log("day_limit");
    return jsonResponse({ error: "Today's voice limit is reached. Try again tomorrow.", code: "day_limit" }, 429);
  }
  const failed = (outcome: string) => {
    log(outcome);
    return jsonResponse({ error: "Could not speak the line", code: "speech_failed" }, 502);
  };
  // The limit covers the wait for OpenAI's answer, not the streaming of the audio after it.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), Number(env.LEARN_AI_TIMEOUT_MS) || SPEECH_TIMEOUT_MS);
  let upstream: Response;
  try {
    upstream = await fetch(new URL("v1/audio/speech", env.OPENAI_API_URL || OPENAI_API_URL), {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({
        model: SPEECH_MODEL,
        voice: parsed.voice,
        input: parsed.text,
        instructions: SPEECH_INSTRUCTIONS,
        response_format: "mp3",
      }),
      signal: controller.signal,
    });
  } catch {
    return failed(controller.signal.aborted ? "timeout" : "network");
  } finally {
    clearTimeout(timer);
  }
  if (!upstream.ok || upstream.body === null) {
    // Read and drop the error body so the connection is released.
    await upstream.body?.cancel();
    return failed(`http_${upstream.status}`);
  }
  log("ok");
  return new Response(upstream.body, {
    status: 200,
    headers: { "content-type": "audio/mpeg", "cache-control": "no-store", ...CORS_HEADERS },
  });
}

export const learnSpeechRoute: RouteDefinition = { method: "POST", pattern: /^\/learn\/speech$/, public: false, handler: handleLearnSpeech };
