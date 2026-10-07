// The story feature's routes, all behind the app secret (`public: false`, sad §5, AC-18).
// The offered AI list, grouping, and the story run routes: start, status, redo and a run's
// picture (sad §6 S-02, S-04, S-05, S-09). Only the app, with its secret, can start a run or a
// redo: nothing here is public and the web pages link to none of it (AC-18).

import { jsonResponse } from "../http";
import type { Env } from "../env";
import type { RouteContext, RouteDefinition } from "../routing";
import { takeDrawAgain, takeStoryRun } from "./allowance.ts";
import { groupWords, parseGroupingRequest } from "./grouping.ts";
import { defaults, isOffered, offeredModels, pricesAsOf } from "./models.ts";
import type { StoryRunParams } from "./run-steps.ts";
import { findCountedRun, getPicture, recordStep, runStatus } from "./store.ts";

/** GET /story/models -- the offered AIs with prices and the defaults (ADR-0004). Owner-only fields stay out. */
async function handleModels(): Promise<Response> {
  const models = offeredModels.map(({ provisional: _provisional, ...model }) => {
    const { request: _request, ...offered } = model as typeof model & { request?: unknown };
    return offered;
  });
  return jsonResponse({ pricesAsOf, defaults, models });
}

/** POST /story/grouping -- the fixed AI's split of the words, returned unchanged (ADR-0005, S-01). */
async function handleGrouping({ request, env }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  const parsed = parseGroupingRequest(body);
  if ("error" in parsed) return jsonResponse({ error: parsed.error }, 400);

  const groups = await groupWords(env, parsed);
  if (!groups) return jsonResponse({ error: "Could not group the words", code: "grouping_failed" }, 502);
  return jsonResponse(groups);
}

// A Workflow instance id is at most 64 characters of letters, digits, `-` and `_`; a redo adds a suffix.
const RUN_ID = /^[A-Za-z0-9_-]{1,40}$/;
const MAX_WORDS = 50;
const MAX_WORD_LENGTH = 100;
const MAX_STATUS_IDS = 50;

const serviceUnavailable = () => jsonResponse({ error: "Story pictures are not available", code: "no_storage" }, 503);
const notOffered = (model: string) => jsonResponse({ error: "That AI is not offered", code: "not_offered", model }, 422);
const dayLimit = () => jsonResponse({ error: "Today's story limit is reached", code: "day_limit" }, 429);

async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const body: unknown = await request.json();
    return typeof body === "object" && body !== null && !Array.isArray(body) ? (body as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/** Starts the Workflow instance named `id`; an instance that already exists is the same run going on. */
async function startInstance(env: Env, id: string, params: StoryRunParams): Promise<void> {
  try {
    await env.STORY_RUN.create({ id, params });
  } catch (err) {
    // A repeated start finds its instance already there, which is exactly right; any other
    // failure means the run never started, which the caller must know.
    try {
      await env.STORY_RUN.get(id);
    } catch {
      throw err;
    }
  }
}

/** POST /story/runs -- check the three AIs, take one unit of the day, start the run (S-02). */
async function handleStart({ request, env }: RouteContext): Promise<Response> {
  const body = await readJson(request);
  if (!body) return jsonResponse({ error: "Body must be a JSON object" }, 400);
  const { runId, words, storyModel, promptModel, pictureModel } = body;
  if (typeof runId !== "string" || !RUN_ID.test(runId)) return jsonResponse({ error: "runId must be 1-40 letters, digits, - or _" }, 400);
  if (
    !Array.isArray(words) ||
    words.length < 1 ||
    words.length > MAX_WORDS ||
    !words.every((w) => typeof w === "string" && w.trim() !== "" && w.length <= MAX_WORD_LENGTH)
  ) {
    return jsonResponse({ error: `words must be 1-${MAX_WORDS} non-empty strings` }, 400);
  }
  if (typeof storyModel !== "string" || typeof promptModel !== "string" || typeof pictureModel !== "string") {
    return jsonResponse({ error: "storyModel, promptModel and pictureModel are required" }, 400);
  }
  if (!env.SOURCES) return serviceUnavailable();

  for (const [role, model] of [["text", storyModel], ["text", promptModel], ["picture", pictureModel]] as const) {
    if (!isOffered(role, model)) return notOffered(model);
  }

  const take = await takeStoryRun(env, { runId, words: words as string[], storyModel, promptModel, pictureModel });
  if (take.outcome === "refused") return dayLimit();
  // `existing` is a repeat of a counted start: free, and the instance is only created if it is missing.
  await startInstance(env, runId, { runId, mode: "full", attempt: 1 });
  return jsonResponse({ started: true });
}

/** GET /story/runs?ids=a,b,c -- the steps so far of several runs, for the app's 5 s poll (S-04). */
async function handleStatus({ env, url }: RouteContext): Promise<Response> {
  const ids = (url.searchParams.get("ids") ?? "").split(",").filter((id) => id !== "");
  if (ids.length === 0 || ids.length > MAX_STATUS_IDS || !ids.every((id) => RUN_ID.test(id))) {
    return jsonResponse({ error: `ids must be 1-${MAX_STATUS_IDS} run ids separated by commas` }, 400);
  }
  return jsonResponse({ runs: await runStatus(env, ids) });
}

/** POST /story/runs/redo -- redo the failed picture prompt step, or Draw again (S-05). */
async function handleRedo({ request, env }: RouteContext): Promise<Response> {
  const body = await readJson(request);
  if (!body) return jsonResponse({ error: "Body must be a JSON object" }, 400);
  const { runId, step, pictureModel } = body;
  if (typeof runId !== "string" || !RUN_ID.test(runId)) return jsonResponse({ error: "runId must be 1-40 letters, digits, - or _" }, 400);
  if (step !== "prompt" && step !== "picture") return jsonResponse({ error: "step must be prompt or picture" }, 400);
  if (pictureModel !== undefined && typeof pictureModel !== "string") return jsonResponse({ error: "pictureModel must be a string" }, 400);
  if (!env.SOURCES) return serviceUnavailable();
  if (pictureModel !== undefined && !isOffered("picture", pictureModel)) return notOffered(pictureModel);

  if (!(await findCountedRun(env, runId))) return jsonResponse({ error: "Unknown run", code: "unknown_run" }, 404);
  const [run] = await runStatus(env, [runId]);
  const stepOf = (role: string, attempt: number) => run.steps.find((s) => s.role === role && s.attempt === attempt);
  const notFailed = () => jsonResponse({ error: "That step has not failed", code: "not_failed" }, 409);
  const suffix = randomSuffix();

  if (step === "prompt") {
    const prompt = stepOf("prompt", 1);
    if (stepOf("story", 1)?.outcome !== "done" || prompt?.outcome !== "failed") return notFailed();
    // Marked running at once, so a second tap before the Workflow starts is refused; no unit is taken.
    await recordStep(env, { runId, role: "prompt", attempt: 1, modelId: prompt.modelId, outcome: "running", startedAt: new Date().toISOString() });
    await startInstance(env, `${runId}-p-${suffix}`, { runId, mode: "prompt", attempt: nextAttempt(run.steps) });
    return jsonResponse({ started: true });
  }

  const pictures = run.steps.filter((s) => s.role === "picture");
  const latest = pictures[pictures.length - 1];
  if (stepOf("prompt", 1)?.outcome !== "done" || latest?.outcome !== "failed") return notFailed();
  const attempt = latest.attempt + 1;
  const take = await takeDrawAgain(env, runId, attempt);
  if (take.outcome === "refused") return take.reason === "day" ? dayLimit() : jsonResponse({ error: "Unknown run", code: "unknown_run" }, 404);
  if (take.outcome === "existing") return notFailed();
  try {
    await startInstance(env, `${runId}-d-${suffix}`, { runId, mode: "picture", pictureModel, attempt });
  } catch (err) {
    // The unit stays taken (a unit is never given back), but the attempt must not look like it is going.
    await recordStep(env, {
      runId, role: "picture", attempt, modelId: pictureModel ?? run.pictureModel, outcome: "failed", priceUsd: 0,
      startedAt: new Date().toISOString(), finishedAt: new Date().toISOString(),
    });
    throw err;
  }
  return jsonResponse({ started: true, attempt });
}

/** GET /story/runs/:runId/pictures/:attempt -- the picture bytes while the Worker still holds them (S-04). */
async function handlePicture({ env, params }: RouteContext): Promise<Response> {
  if (!env.SOURCES) return serviceUnavailable();
  const attempt = Number(params.attempt);
  if (!RUN_ID.test(params.runId) || !Number.isInteger(attempt) || attempt < 1) return jsonResponse({ error: "Not found" }, 404);
  const found = await getPicture(env, params.runId, attempt);
  if (!found) return jsonResponse({ error: "Not found" }, 404);
  return new Response(found.bytes, { headers: { "content-type": found.contentType, "cache-control": "no-store" } });
}

const randomSuffix = () => crypto.randomUUID().replaceAll("-", "").slice(0, 12);
const nextAttempt = (steps: { role: string; attempt: number }[]) =>
  Math.max(1, ...steps.filter((s) => s.role === "picture").map((s) => s.attempt + 1));

export const storyRoutes: RouteDefinition[] = [
  { method: "GET", pattern: /^\/story\/models$/, public: false, handler: handleModels },
  { method: "POST", pattern: /^\/story\/grouping$/, public: false, handler: handleGrouping },
  { method: "POST", pattern: /^\/story\/runs$/, public: false, handler: handleStart },
  { method: "GET", pattern: /^\/story\/runs$/, public: false, handler: handleStatus },
  { method: "POST", pattern: /^\/story\/runs\/redo$/, public: false, handler: handleRedo },
  { method: "GET", pattern: /^\/story\/runs\/(?<runId>[^/]+)\/pictures\/(?<attempt>[^/]+)$/, public: false, handler: handlePicture },
];
