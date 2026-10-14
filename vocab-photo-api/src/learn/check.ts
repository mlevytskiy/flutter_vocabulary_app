// POST /learn/check -- the sentence check (learn-kit, H-03, H-04, S-19, S-20, S-24). One fixed-Haiku
// call per learner sentence, never cached and never logged with the sentence. `usesWord` is the
// Worker's own word match (word-check.ts, the app's rule too), not the AI's; the app makes the final
// verdict (judgeCheck, S-21).
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { jsonResponse } from "../http.ts";
import { logEvent } from "../log.ts";
import type { RouteContext, RouteDefinition } from "../routing";
import { GROUPING_MODEL } from "../story/models.ts";
import { writeText } from "../story/providers/text.ts";
import { matchPlaces } from "../story/word-check.ts";
import { checkPrompt, type LearnCheckTask } from "./prompts.ts";

const TASKS: readonly LearnCheckTask[] = ["pattern", "own", "translate", "explain"];
const MAX_WORD_LENGTH = 100;
const MAX_TRANSLATION_LENGTH = 200;
const MAX_SENTENCE_LENGTH = 200;
const MAX_EXPLANATION_LENGTH = 300;
const MAX_EXTRA_LENGTH = 300;
const MAX_NOTE_LENGTH = 100;
const CHECK_MAX_OUTPUT_TOKENS = 300;
/** The app gives up at 15 s (D-25), so the Worker's 12 s wins. */
const CHECK_TIMEOUT_MS = 12_000;

export interface LearnCheckRequest {
  word: string;
  translation: string;
  sentence: string;
  task: LearnCheckTask;
  extra: string;
}

export interface CheckReply {
  usesWord?: boolean;
  usesTask: boolean;
  ok: boolean;
  fixed: string;
  note: string;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** The check request, or the reason it is not one (AC-30). */
export function parseCheckRequest(body: unknown): (LearnCheckRequest & { error?: undefined }) | { error: string } {
  if (!isRecord(body)) return { error: "Body must be a JSON object" };
  const { word, translation = "", sentence, task, extra = "" } = body;
  if (!TASKS.includes(task as LearnCheckTask)) return { error: `task must be one of ${TASKS.join(", ")}` };
  if (typeof word !== "string" || word.trim() === "" || word.length > MAX_WORD_LENGTH) return { error: `word must be 1-${MAX_WORD_LENGTH} characters` };
  if (typeof translation !== "string" || translation.length > MAX_TRANSLATION_LENGTH) {
    return { error: `translation may hold at most ${MAX_TRANSLATION_LENGTH} characters` };
  }
  if (typeof extra !== "string" || extra.length > MAX_EXTRA_LENGTH) return { error: `extra may hold at most ${MAX_EXTRA_LENGTH} characters` };
  if (typeof sentence !== "string") return { error: "Write a full sentence" };
  const text = sentence.trim();
  if (text.split(/\s+/).filter((w) => w !== "").length < 2) return { error: "Write a full sentence" };
  const max = task === "explain" ? MAX_EXPLANATION_LENGTH : MAX_SENTENCE_LENGTH;
  if (text.length > max) return { error: `Keep it under ${max} characters` };
  return { word, translation, sentence, task: task as LearnCheckTask, extra };
}

/** The AI's verdict (a fenced block is allowed), or undefined when it cannot be read. */
export function parseCheckReply(reply: string): CheckReply | undefined {
  const trimmed = reply.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  let parsed: unknown;
  try {
    parsed = JSON.parse(fenced ? fenced[1] : trimmed);
  } catch {
    return undefined;
  }
  if (!isRecord(parsed) || typeof parsed.ok !== "boolean" || typeof parsed.usesTask !== "boolean") return undefined;
  return {
    usesWord: typeof parsed.usesWord === "boolean" ? parsed.usesWord : undefined,
    usesTask: parsed.usesTask,
    ok: parsed.ok,
    fixed: typeof parsed.fixed === "string" ? parsed.fixed.trim() : "",
    note: typeof parsed.note === "string" ? parsed.note.trim() : "",
  };
}

/** At most 100 characters, cut at a word when there is one to cut at (S-20). */
export function cutNote(note: string): string {
  if (note.length <= MAX_NOTE_LENGTH) return note;
  const head = note.slice(0, MAX_NOTE_LENGTH + 1);
  const space = head.lastIndexOf(" ");
  return (space > 0 ? head.slice(0, space) : note.slice(0, MAX_NOTE_LENGTH)).trimEnd();
}

const badRequest = (error: string) => jsonResponse({ error, code: "bad_request" }, 400);

async function handleLearnCheck({ request, env }: RouteContext): Promise<Response> {
  const started = Date.now();
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return badRequest("Body must be JSON");
  }
  const parsed = parseCheckRequest(body);
  if (parsed.error !== undefined) return badRequest(parsed.error);
  const { word, translation, sentence, task, extra } = parsed;
  // Never the sentence or the explanation (S-24).
  const log = (outcome: string, reply?: CheckReply) =>
    logEvent("learn check", { task, aiOk: reply?.ok ?? null, aiUsesWord: reply?.usesWord ?? null, outcome, ms: Date.now() - started });

  const { system, user } = checkPrompt({ word, translation, sentence, task, extra });
  const result = await writeText(env, {
    model: GROUPING_MODEL,
    system,
    user,
    maxOutputTokens: CHECK_MAX_OUTPUT_TOKENS,
    timeoutMs: Number(env.LEARN_AI_TIMEOUT_MS) || CHECK_TIMEOUT_MS,
  });
  const reply = result.failed === undefined ? parseCheckReply(result.text) : undefined;
  if (!reply) {
    log(result.failed ?? "unreadable");
    return jsonResponse({ error: "Could not check the sentence", code: "check_failed" }, 502);
  }
  log("ok", reply);
  return jsonResponse({
    usesWord: matchPlaces(sentence, word).length > 0,
    usesTask: reply.usesTask,
    ok: reply.ok,
    fixed: reply.ok || task === "explain" ? "" : reply.fixed,
    note: cutNote(reply.note),
  });
}

export const learnCheckRoute: RouteDefinition = { method: "POST", pattern: /^\/learn\/check$/, public: false, handler: handleLearnCheck };
