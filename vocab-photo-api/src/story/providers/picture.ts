// The picture step of a story run: one `drawPicture` shape over every picture provider
// (sad §4 "New providers", spec AC-09). A refusal, an error or no picture in time is
// returned as a failure, never thrown, so the run can mark the step failed with its price
// and time. The whole call (Higgsfield's submit, polling and download included) is aborted
// at 120 s (AC-08b).
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { offeredModels } from "../models.ts";
import { drawWithHiggsfield } from "./higgsfield.ts";
import { drawWithXai } from "./xai.ts";

/** Each picture call, polling included, is aborted after 120 s (AC-08b). */
export const DEFAULT_PICTURE_TIMEOUT_MS = 120_000;
/** How often Higgsfield's job is polled, in ms. */
export const DEFAULT_POLL_INTERVAL_MS = 2_000;

/** The part of the Worker's env the picture adapters read. */
export interface PictureEnv {
  XAI_API_KEY: string;
  XAI_API_URL?: string;
  HIGGSFIELD_API_KEY: string;
  HIGGSFIELD_API_URL?: string;
  /** Overrides the 120 s limit, in ms; unset in production. The tests shorten it. */
  STORY_PICTURE_TIMEOUT_MS?: string;
  /** Overrides the Higgsfield polling interval, in ms; unset in production. */
  STORY_PICTURE_POLL_MS?: string;
}

export interface PictureRequest {
  /** An offered picture model id (models.json). */
  model: string;
  prompt: string;
  /** Overrides the limit for this call; otherwise the env override, otherwise 120 s. */
  timeoutMs?: number;
}

export type PictureFailure = "refused" | "error" | "timeout";

export type PictureResult =
  | { failed?: undefined; bytes: Uint8Array; contentType: string }
  | { failed: PictureFailure; bytes?: undefined; contentType?: undefined };

/** What an adapter needs: the chosen model, the key and base URL, and the abort signal. */
export interface PictureAdapterCall {
  model: string;
  prompt: string;
  apiKey: string;
  baseUrl?: string;
  pollIntervalMs: number;
  signal: AbortSignal;
}

export type PictureAdapter = (call: PictureAdapterCall) => Promise<PictureResult>;

export async function drawPicture(env: PictureEnv, req: PictureRequest): Promise<PictureResult> {
  const model = offeredModels.find((m) => m.id === req.model);
  if (!model || model.role !== "picture") throw new Error(`not an offered picture model: ${req.model}`);

  let adapter: PictureAdapter;
  let credentials: { apiKey: string; baseUrl?: string };
  switch (model.provider) {
    case "xai":
      adapter = drawWithXai;
      credentials = { apiKey: env.XAI_API_KEY, baseUrl: env.XAI_API_URL };
      break;
    case "higgsfield":
      adapter = drawWithHiggsfield;
      credentials = { apiKey: env.HIGGSFIELD_API_KEY, baseUrl: env.HIGGSFIELD_API_URL };
      break;
    default:
      throw new Error(`no picture adapter for provider: ${model.provider}`);
  }

  const timeoutMs = req.timeoutMs ?? (Number(env.STORY_PICTURE_TIMEOUT_MS) || DEFAULT_PICTURE_TIMEOUT_MS);
  const pollIntervalMs = Number(env.STORY_PICTURE_POLL_MS) || DEFAULT_POLL_INTERVAL_MS;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await adapter({ model: req.model, prompt: req.prompt, ...credentials, pollIntervalMs, signal: controller.signal });
  } catch {
    // An abort surfaces as an AbortError; anything else (network, bad JSON) is an error.
    return { failed: controller.signal.aborted ? "timeout" : "error" };
  } finally {
    clearTimeout(timer);
  }
}

/** Waits `ms`, or rejects at once when the signal aborts. */
export function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) return reject(signal.reason);
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(timer);
      reject(signal.reason);
    };
    signal.addEventListener("abort", onAbort, { once: true });
  });
}
