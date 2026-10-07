// The steps of one story run (mnemonic-story, ADR-0002, sad §6 S-03): story writer ->
// word check -> picture prompt writer -> picture maker. Each paid step runs inside one
// durable `step.do` with no retry and records its own result or failure, price, time and
// missed words to D1; the picture goes to R2. This module holds no Workflows import, so
// the Node tests can run it with a stand-in `step.do`; `workflow.ts` is the thin class.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import type { Env } from "../env";
import { estimateOnTimeout, priceOf, type Price, type Usage } from "./models.ts";
import { buildPicturePrompt, parsePictureScenes, picturePromptWriterPrompt, splitCaptions, storyWriterPrompt, type Prompt } from "./prompts.ts";
import { drawPicture } from "./providers/picture.ts";
import { DEFAULT_MAX_OUTPUT_TOKENS, writeText } from "./providers/text.ts";
import { findCountedRun, putPicture, recordStep, runStatus, type StepRecord, type StepRole } from "./store.ts";
import { missedWords } from "./word-check.ts";

/** What starts a Workflow instance. A redo of one step is a new instance of the same run. */
export interface StoryRunParams {
  runId: string;
  /** `full`: every step. `prompt`: the picture prompt step from the same story, then the picture. `picture`: the picture only. */
  mode: "full" | "prompt" | "picture";
  /** The picture AI for this instance; otherwise the one the run was started with. */
  pictureModel?: string;
  /** The picture attempt this instance makes (1 for the first, then one more per "Draw again"). */
  attempt: number;
}

/** The part of the Workflows `step` the steps use. */
export interface StepRunner {
  do<T>(name: string, config: typeof STEP_CONFIG, fn: () => Promise<T>): Promise<T>;
}

/** Paid steps never retry: a failed step is recorded as failed and the learner decides (AC-08b, AC-09). */
export const STEP_CONFIG = {
  retries: { limit: 0, delay: 0 },
  // Above the longest provider limit (120 s) plus recording; the provider calls abort themselves.
  timeout: "4 minutes",
} as const;

type RunEnv = Pick<Env, "DB" | "SOURCES"> &
  Pick<
    Env,
    | "ANTHROPIC_API_KEY"
    | "ANTHROPIC_API_URL"
    | "OPENCODE_ZEN_API_KEY"
    | "OPENCODE_ZEN_API_URL"
    | "STORY_TEXT_TIMEOUT_MS"
    | "XAI_API_KEY"
    | "XAI_API_URL"
    | "HIGGSFIELD_API_KEY"
    | "HIGGSFIELD_API_URL"
    | "STORY_PICTURE_TIMEOUT_MS"
    | "STORY_PICTURE_POLL_MS"
  >;

interface RunInput {
  words: string[];
  storyModel: string;
  promptModel: string;
  pictureModel: string;
  /** The finished story and picture prompt kept by earlier steps (a redo starts from them). */
  story: string | null;
  prompt: string | null;
}

/** The result a step returns to the engine: small and serializable (never picture bytes). */
interface StepResult {
  ok: boolean;
  text?: string;
}

const ATTEMPT_1 = 1;
const PRIVATE_FAILURE: StepResult = { ok: false };

/** About 4 characters to a token: the input size of a timed-out step, for its estimated price. */
const inputTokens = (prompt: Prompt) => Math.ceil((prompt.system.length + prompt.user.length) / 4);

/** Runs the steps `params.mode` asks for. A run the Worker never counted runs nothing (AC-19). */
export async function runStoryRun(env: RunEnv, runner: StepRunner, params: StoryRunParams): Promise<void> {
  const input = await runner.do("load run", STEP_CONFIG, () => loadRun(env, params.runId));
  if (!input) return;

  let story = input.story;
  let prompt = input.prompt;

  if (params.mode === "full") {
    const result = await runner.do("story", STEP_CONFIG, () => storyStep(env, params, input));
    if (!result.ok) return;
    story = result.text ?? null;
  }
  if (params.mode !== "picture") {
    const result = await runner.do("prompt", STEP_CONFIG, () => promptStep(env, params, input, story));
    if (!result.ok) return;
    prompt = result.text ?? null;
  }
  await runner.do("picture", STEP_CONFIG, () => pictureStep(env, params, input, prompt));
}

async function loadRun(env: RunEnv, runId: string): Promise<RunInput | null> {
  if (!(await findCountedRun(env, runId))) return null;
  const [run] = await runStatus(env, [runId]);
  const text = (role: StepRole) =>
    run.steps.find((s) => s.role === role && s.attempt === ATTEMPT_1 && s.outcome === "done")?.text ?? null;
  return {
    words: run.words,
    storyModel: run.storyModel,
    promptModel: run.promptModel,
    pictureModel: run.pictureModel,
    story: text("story"),
    prompt: text("prompt"),
  };
}

/** Writes the step's running row, so the app sees which step is going, then returns the clock. */
async function begin(env: RunEnv, runId: string, role: StepRole, attempt: number, modelId: string) {
  const startedAt = new Date();
  await recordStep(env, { runId, role, attempt, modelId, outcome: "running", startedAt: startedAt.toISOString() });
  return startedAt;
}

async function finish(env: RunEnv, startedAt: Date, step: Omit<StepRecord, "startedAt" | "finishedAt" | "ms">) {
  const now = new Date();
  await recordStep(env, {
    ...step,
    startedAt: startedAt.toISOString(),
    finishedAt: now.toISOString(),
    ms: now.getTime() - startedAt.getTime(),
  });
}

function priced(price: Price) {
  return { priceUsd: price.usd, priceEstimated: price.estimated };
}

/** One text call and its record. Returns the text when the step is done, or what a failed step records. */
async function textStep(
  env: RunEnv,
  params: StoryRunParams,
  role: "story" | "prompt",
  modelId: string,
  prompt: Prompt
): Promise<{ text: string | null; record: Omit<StepRecord, "startedAt" | "finishedAt" | "ms">; startedAt: Date }> {
  const base = { runId: params.runId, role, attempt: ATTEMPT_1, modelId };
  const startedAt = await begin(env, params.runId, role, ATTEMPT_1, modelId);
  try {
    const result = await writeText(env, { model: modelId, ...prompt });
    if (!result.failed) {
      return { text: result.text, startedAt, record: { ...base, outcome: "done", text: result.text, ...priced(priceOf(result.usage)) } };
    }
    // A refusal that reports its tokens is charged for them; a timeout reports none, so it is
    // estimated (always "≈"); another error reached no usable answer and costs nothing.
    const usage: Usage | undefined = result.usage;
    const price: Price = usage
      ? priceOf(usage)
      : result.failed === "timeout"
        ? estimateOnTimeout(modelId, inputTokens(prompt), DEFAULT_MAX_OUTPUT_TOKENS)
        : { usd: 0, estimated: false };
    return { text: null, startedAt, record: { ...base, outcome: "failed", ...priced(price) } };
  } catch {
    return { text: null, startedAt, record: { ...base, outcome: "failed", priceUsd: 0, priceEstimated: false } };
  }
}

async function storyStep(env: RunEnv, params: StoryRunParams, input: RunInput): Promise<StepResult> {
  const { text, record, startedAt } = await textStep(env, params, "story", input.storyModel, storyWriterPrompt(input.words));
  if (text === null) {
    await finish(env, startedAt, record);
    return PRIVATE_FAILURE;
  }
  // Every word of the group must be there as written, or the picture is not drawn (AC-08).
  const missed = missedWords(text, input.words);
  if (missed.length > 0) {
    await finish(env, startedAt, { ...record, outcome: "failed", missedWords: missed });
    return PRIVATE_FAILURE;
  }
  await finish(env, startedAt, record);
  return { ok: true, text };
}

async function promptStep(env: RunEnv, params: StoryRunParams, input: RunInput, story: string | null): Promise<StepResult> {
  if (story === null) {
    // A prompt redo needs the story an earlier instance finished; without it there is nothing to write from.
    const startedAt = await begin(env, params.runId, "prompt", ATTEMPT_1, input.promptModel);
    await finish(env, startedAt, { runId: params.runId, role: "prompt", attempt: ATTEMPT_1, modelId: input.promptModel, outcome: "failed", priceUsd: 0 });
    return PRIVATE_FAILURE;
  }
  // The captions are the story's own sentences; the AI only adds a character and a scene for each,
  // and the image prompt is assembled here so the captions reach the picture maker verbatim.
  const captions = splitCaptions(story);
  const { text, record, startedAt } = await textStep(env, params, "prompt", input.promptModel, picturePromptWriterPrompt(captions));
  if (text === null) {
    await finish(env, startedAt, record);
    return PRIVATE_FAILURE;
  }
  const scenes = captions.length > 0 ? parsePictureScenes(text, captions.length) : null;
  if (scenes === null) {
    // An unusable reply was still paid for: the step fails with the price its usage gave.
    await finish(env, startedAt, { ...record, outcome: "failed", text: undefined });
    return PRIVATE_FAILURE;
  }
  const prompt = buildPicturePrompt({ character: scenes.character, captions, scenes: scenes.scenes });
  await finish(env, startedAt, { ...record, text: prompt });
  return { ok: true, text: prompt };
}

async function pictureStep(env: RunEnv, params: StoryRunParams, input: RunInput, prompt: string | null): Promise<StepResult> {
  const modelId = params.pictureModel ?? input.pictureModel;
  const base = { runId: params.runId, role: "picture" as const, attempt: params.attempt, modelId };
  const startedAt = await begin(env, params.runId, "picture", params.attempt, modelId);
  if (prompt === null) {
    await finish(env, startedAt, { ...base, outcome: "failed", priceUsd: 0 });
    return PRIVATE_FAILURE;
  }
  try {
    const result = await drawPicture(env, { model: modelId, prompt });
    if (!result.failed) {
      const bytes = result.bytes.buffer.slice(result.bytes.byteOffset, result.bytes.byteOffset + result.bytes.byteLength) as ArrayBuffer;
      const pictureKey = await putPicture(env, params.runId, params.attempt, bytes, result.contentType);
      await finish(env, startedAt, { ...base, outcome: "done", pictureKey, ...priced(priceOf({ modelId })) });
      return { ok: true };
    }
    // The picture maker reports no usage: a timeout is charged its picture price as an estimate;
    // a refusal or an error produced no picture.
    const price: Price = result.failed === "timeout" ? estimateOnTimeout(modelId, 0, 0) : { usd: 0, estimated: false };
    await finish(env, startedAt, { ...base, outcome: "failed", ...priced(price) });
  } catch {
    await finish(env, startedAt, { ...base, outcome: "failed", priceUsd: 0 });
  }
  return PRIVATE_FAILURE;
}
