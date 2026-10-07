import type { Env } from "../env";

/**
 * The Worker's copy of story runs (mnemonic-story, sad §1 override, ADR-0002): run and
 * step rows in D1 are kept with no expiry; a run's picture lives in R2 `SOURCES` under
 * `story-runs/<runId>/<attempt>` until the app has collected it or 7 days have passed.
 * The phone keeps the copy the learner sees.
 */
export const PICTURE_MAX_AGE_DAYS = 7;
const PICTURE_PREFIX = "story-runs/";
// D1 allows 100 bound values in one statement; a status call binds one per run id.
const ID_CHUNK = 50;

export type StepRole = "story" | "prompt" | "picture";
export type StepOutcome = "running" | "done" | "failed";

export interface NewStoryRun {
  runId: string;
  /** The English words the story is about. */
  words: string[];
  storyModel: string;
  promptModel: string;
  pictureModel: string;
}

export interface StoryRunRecord extends NewStoryRun {
  createdAt: string;
}

export interface StepRecord {
  runId: string;
  role: StepRole;
  attempt: number;
  modelId: string;
  outcome: StepOutcome;
  text?: string | null;
  missedWords?: string[] | null;
  pictureKey?: string | null;
  priceUsd?: number | null;
  priceEstimated?: boolean;
  ms?: number | null;
  startedAt: string;
  finishedAt?: string | null;
}

export type StepStatus = Omit<Required<StepRecord>, "runId">;

export interface RunStatus extends StoryRunRecord {
  /** Every attempt, in step order (story, prompt, picture) then attempt. */
  steps: StepStatus[];
}

interface RunRow {
  run_id: string;
  created_at: string;
  words_json: string;
  story_model: string;
  prompt_model: string;
  picture_model: string;
}

interface StepRow {
  run_id: string;
  role: StepRole;
  attempt: number;
  model_id: string;
  outcome: StepOutcome;
  text: string | null;
  missed_words_json: string | null;
  picture_key: string | null;
  price_usd: number | null;
  price_estimated: number;
  ms: number | null;
  started_at: string;
  finished_at: string | null;
}

function toRun(row: RunRow): StoryRunRecord {
  return {
    runId: row.run_id,
    createdAt: row.created_at,
    words: JSON.parse(row.words_json) as string[],
    storyModel: row.story_model,
    promptModel: row.prompt_model,
    pictureModel: row.picture_model,
  };
}

function toStep(row: StepRow): StepStatus & { runId: string } {
  return {
    runId: row.run_id,
    role: row.role,
    attempt: row.attempt,
    modelId: row.model_id,
    outcome: row.outcome,
    text: row.text,
    missedWords: row.missed_words_json === null ? null : (JSON.parse(row.missed_words_json) as string[]),
    pictureKey: row.picture_key,
    priceUsd: row.price_usd,
    priceEstimated: row.price_estimated === 1,
    ms: row.ms,
    startedAt: row.started_at,
    finishedAt: row.finished_at,
  };
}

/** Inserts a run row; false when the run id already exists. Takes no allowance (see `takeStoryRun`). */
export async function createRun(env: Pick<Env, "DB">, run: NewStoryRun, now = new Date()): Promise<boolean> {
  const result = await env.DB.prepare(
    `INSERT OR IGNORE INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6)`
  )
    .bind(run.runId, now.toISOString(), JSON.stringify(run.words), run.storyModel, run.promptModel, run.pictureModel)
    .run();
  return result.meta.changes === 1;
}

/** The run, or null for an id that was never counted (a step for it is refused, AC-19). */
export async function findCountedRun(env: Pick<Env, "DB">, runId: string): Promise<StoryRunRecord | null> {
  const { results } = await env.DB.prepare(`SELECT * FROM story_runs WHERE run_id = ?1`).bind(runId).all<RunRow>();
  return results.length > 0 ? toRun(results[0]) : null;
}

/** Writes one attempt of one step: a new row, or the result of the row already there. */
export async function recordStep(env: Pick<Env, "DB">, step: StepRecord): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO story_run_steps
       (run_id, role, attempt, model_id, outcome, text, missed_words_json, picture_key, price_usd, price_estimated, ms, started_at, finished_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
     ON CONFLICT (run_id, role, attempt) DO UPDATE SET
       model_id = excluded.model_id, outcome = excluded.outcome, text = excluded.text,
       missed_words_json = excluded.missed_words_json, picture_key = excluded.picture_key,
       price_usd = excluded.price_usd, price_estimated = excluded.price_estimated, ms = excluded.ms,
       started_at = excluded.started_at, finished_at = excluded.finished_at`
  )
    .bind(
      step.runId,
      step.role,
      step.attempt,
      step.modelId,
      step.outcome,
      step.text ?? null,
      step.missedWords ? JSON.stringify(step.missedWords) : null,
      step.pictureKey ?? null,
      step.priceUsd ?? null,
      step.priceEstimated ? 1 : 0,
      step.ms ?? null,
      step.startedAt,
      step.finishedAt ?? null
    )
    .run();
}

/** The runs among `runIds` with all their steps; ids the Worker never counted are left out. */
export async function runStatus(env: Pick<Env, "DB">, runIds: string[]): Promise<RunStatus[]> {
  const out: RunStatus[] = [];
  for (let i = 0; i < runIds.length; i += ID_CHUNK) {
    const ids = runIds.slice(i, i + ID_CHUNK);
    const marks = ids.map((_, n) => `?${n + 1}`).join(", ");
    const [runs, steps] = await env.DB.batch([
      env.DB.prepare(`SELECT * FROM story_runs WHERE run_id IN (${marks})`).bind(...ids),
      env.DB.prepare(
        `SELECT * FROM story_run_steps WHERE run_id IN (${marks})
         ORDER BY CASE role WHEN 'story' THEN 0 WHEN 'prompt' THEN 1 ELSE 2 END, attempt`
      ).bind(...ids),
    ]);
    const byRun = new Map<string, StepStatus[]>();
    for (const row of steps.results as StepRow[]) {
      const { runId, ...step } = toStep(row);
      byRun.set(runId, [...(byRun.get(runId) ?? []), step]);
    }
    for (const row of runs.results as RunRow[]) out.push({ ...toRun(row), steps: byRun.get(row.run_id) ?? [] });
  }
  return out;
}

export function pictureKey(runId: string, attempt: number): string {
  return `${PICTURE_PREFIX}${runId}/${attempt}`;
}

/** Stores a picture and returns its R2 key. */
export async function putPicture(
  env: Pick<Env, "SOURCES">,
  runId: string,
  attempt: number,
  bytes: ArrayBuffer,
  contentType: string
): Promise<string> {
  if (!env.SOURCES) throw new Error("SOURCES binding is not configured");
  const key = pictureKey(runId, attempt);
  await env.SOURCES.put(key, bytes, { httpMetadata: { contentType } });
  return key;
}

/** The picture's bytes, or null when it is not held (never made, collected, or cleaned up). */
export async function getPicture(
  env: Pick<Env, "SOURCES">,
  runId: string,
  attempt: number
): Promise<{ bytes: ArrayBuffer; contentType: string } | null> {
  if (!env.SOURCES) return null;
  const object = await env.SOURCES.get(pictureKey(runId, attempt));
  if (!object) return null;
  return { bytes: await object.arrayBuffer(), contentType: object.httpMetadata?.contentType ?? "application/octet-stream" };
}

/** Deletes a collected picture; its step row stays, without the key. */
export async function deletePicture(env: Pick<Env, "DB" | "SOURCES">, runId: string, attempt: number): Promise<void> {
  if (!env.SOURCES) return;
  const key = pictureKey(runId, attempt);
  await env.SOURCES.delete(key);
  await env.DB.prepare(`UPDATE story_run_steps SET picture_key = NULL WHERE picture_key = ?1`).bind(key).run();
}

/**
 * The daily clean-up: deletes run pictures uploaded more than 7 days before `now` and
 * clears their step keys. Run and step rows are all kept. Returns how many were deleted.
 */
export async function deleteOldPictures(env: Pick<Env, "DB" | "SOURCES">, now = new Date()): Promise<number> {
  if (!env.SOURCES) return 0;
  const cutoff = now.getTime() - PICTURE_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;
  let deleted = 0;
  let cursor: string | undefined;
  do {
    const page = await env.SOURCES.list({ prefix: PICTURE_PREFIX, cursor });
    const old = page.objects.filter((o) => o.uploaded.getTime() < cutoff).map((o) => o.key);
    if (old.length > 0) {
      await env.SOURCES.delete(old);
      await env.DB.batch(
        old.map((key) => env.DB.prepare(`UPDATE story_run_steps SET picture_key = NULL WHERE picture_key = ?1`).bind(key))
      );
      deleted += old.length;
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return deleted;
}
