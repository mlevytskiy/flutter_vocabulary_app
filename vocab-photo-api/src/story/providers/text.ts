// The text step of a story run: one `writeText` shape over every text provider
// (sad §4 "New providers", spec AC-08b). The story writer and the picture prompt writer
// both go through it. A refusal, an error or no answer in time is returned as a failure,
// never thrown, so the run can mark the step failed with its price and time.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { GROUPING_MODEL, offeredModels, type Usage } from "../models.ts";
import { writeWithAnthropic } from "./anthropic.ts";
import { writeWithZen } from "./opencode-zen.ts";

/** Each text call is aborted after 90 s (AC-08b). */
export const DEFAULT_TEXT_TIMEOUT_MS = 90_000;
/** Output limit of one text call; a story for 19 words fits well inside it. */
export const DEFAULT_MAX_OUTPUT_TOKENS = 4000;

/** The part of the Worker's env the text adapters read. */
export interface TextEnv {
  ANTHROPIC_API_KEY: string;
  ANTHROPIC_API_URL?: string;
  OPENCODE_ZEN_API_KEY: string;
  OPENCODE_ZEN_API_URL?: string;
  /** Overrides the 90 s limit, in ms; unset in production. The tests shorten it. */
  STORY_TEXT_TIMEOUT_MS?: string;
}

export interface TextRequest {
  /** An offered text model id (models.json). */
  model: string;
  system: string;
  user: string;
  /** Overrides the limit for this call; otherwise the env override, otherwise 90 s. */
  timeoutMs?: number;
  maxOutputTokens?: number;
}

export type TextFailure = "refused" | "error" | "timeout";

export type TextResult =
  | { failed?: undefined; text: string; usage: Usage }
  /** `usage` is set when the provider reported it (a refusal still costs tokens); a timeout reports none. */
  | { failed: TextFailure; text?: undefined; usage?: Usage };

/** What an adapter needs: the chosen model, the key and base URL, and the abort signal's limit. */
export interface AdapterCall {
  model: string;
  system: string;
  user: string;
  apiKey: string;
  baseUrl?: string;
  maxOutputTokens: number;
  signal: AbortSignal;
}

export type Adapter = (call: AdapterCall) => Promise<TextResult>;

export async function writeText(env: TextEnv, req: TextRequest): Promise<TextResult> {
  // The fixed grouping AI is not on the offered list (it is not choosable) but goes through here too.
  const model =
    req.model === GROUPING_MODEL
      ? { role: "text", provider: "anthropic" }
      : offeredModels.find((m) => m.id === req.model);
  if (!model || model.role !== "text") throw new Error(`not an offered text model: ${req.model}`);

  const call = {
    model: req.model,
    system: req.system,
    user: req.user,
    maxOutputTokens: req.maxOutputTokens ?? DEFAULT_MAX_OUTPUT_TOKENS,
  };
  let adapter: Adapter;
  let credentials: { apiKey: string; baseUrl?: string };
  switch (model.provider) {
    case "anthropic":
      adapter = writeWithAnthropic;
      credentials = { apiKey: env.ANTHROPIC_API_KEY, baseUrl: env.ANTHROPIC_API_URL };
      break;
    case "opencode-zen":
      adapter = writeWithZen;
      credentials = { apiKey: env.OPENCODE_ZEN_API_KEY, baseUrl: env.OPENCODE_ZEN_API_URL };
      break;
    default:
      throw new Error(`no text adapter for provider: ${model.provider}`);
  }

  const timeoutMs = req.timeoutMs ?? (Number(env.STORY_TEXT_TIMEOUT_MS) || DEFAULT_TEXT_TIMEOUT_MS);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await adapter({ ...call, ...credentials, signal: controller.signal });
  } catch (err) {
    // An abort surfaces as an AbortError; anything else (network, bad JSON) is an error.
    return { failed: controller.signal.aborted ? "timeout" : "error" };
  } finally {
    clearTimeout(timer);
  }
}

/** Joins a base URL and a path whatever the base's trailing slash. */
export function endpoint(baseUrl: string | undefined, fallback: string, path: string): URL {
  const base = baseUrl || fallback;
  return new URL(path, base.endsWith("/") ? base : base + "/");
}
