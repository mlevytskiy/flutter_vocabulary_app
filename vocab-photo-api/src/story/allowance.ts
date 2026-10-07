import type { Env } from "../env";
import type { NewStoryRun } from "./store.ts";

/**
 * The story allowance (mnemonic-story ADR-0002, sad §4, §8, AC-19): at most 20 story
 * runs a UTC day across the whole app. A new run takes one unit when its story step
 * starts and each "Draw again" takes one; a repeated start, a step that carries on
 * after the app comes back (AC-10) and redoing the picture prompt take none. A unit is
 * never given back when a step fails. Unlike `takeSubtitleImport` there is no
 * per-address window: the per-address rate limiter already applies.
 */
export const STORY_DAY_LIMIT = 20;

export type StoryTake =
  | { outcome: "taken" }
  /** The run (or the Draw again attempt) is already counted: nothing was taken. */
  | { outcome: "existing" }
  | { outcome: "refused"; reason: "day" | "unknown_run" };

/**
 * Counts a new run: inserts its row and takes one unit of the UTC day, or neither, in
 * one D1 batch (one transaction). The day is raised only while below the limit and only
 * if the run id is new, and the run row is inserted only if that raise happened
 * (`changes()` is the row count of the batch's previous statement). So two starts racing
 * for the last unit cannot both get it, and a run is counted exactly when a unit is taken.
 */
export async function takeStoryRun(env: Pick<Env, "DB">, run: NewStoryRun, now = new Date()): Promise<StoryTake> {
  const day = now.toISOString().slice(0, 10);
  const [, taken, , exists] = await env.DB.batch([
    env.DB.prepare(`INSERT OR IGNORE INTO all_story_runs (utc_day, used) VALUES (?1, 0)`).bind(day),
    env.DB.prepare(
      `UPDATE all_story_runs SET used = used + 1
       WHERE utc_day = ?1 AND used < ${STORY_DAY_LIMIT}
         AND NOT EXISTS (SELECT 1 FROM story_runs WHERE run_id = ?2)`
    ).bind(day, run.runId),
    env.DB.prepare(
      `INSERT INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model)
       SELECT ?1, ?2, ?3, ?4, ?5, ?6 WHERE changes() = 1`
    ).bind(run.runId, now.toISOString(), JSON.stringify(run.words), run.storyModel, run.promptModel, run.pictureModel),
    env.DB.prepare(`SELECT EXISTS (SELECT 1 FROM story_runs WHERE run_id = ?1) AS found`).bind(run.runId),
  ]);
  if (taken.meta.changes === 1) return { outcome: "taken" };
  // Not taken: the run was already there, or the day is used up. A run that is there is
  // free to repeat even on a used-up day.
  return (exists.results as { found: number }[])[0].found === 1
    ? { outcome: "existing" }
    : { outcome: "refused", reason: "day" };
}

/**
 * Takes one unit for "Draw again" attempt `attempt` of a counted run and records that
 * attempt's picture step as running, in one batch. An unknown run takes nothing
 * (AC-19: a step that does not belong to a counted run is refused); the same attempt
 * again takes nothing.
 */
export async function takeDrawAgain(
  env: Pick<Env, "DB">,
  runId: string,
  attempt: number,
  now = new Date()
): Promise<StoryTake> {
  const day = now.toISOString().slice(0, 10);
  const run = `EXISTS (SELECT 1 FROM story_runs WHERE run_id = ?2)`;
  const step = `EXISTS (SELECT 1 FROM story_run_steps WHERE run_id = ?2 AND role = 'picture' AND attempt = ?3)`;
  const [, taken, , state] = await env.DB.batch([
    env.DB.prepare(`INSERT OR IGNORE INTO all_story_runs (utc_day, used) SELECT ?1, 0 WHERE ${run}`).bind(day, runId, attempt),
    env.DB.prepare(
      `UPDATE all_story_runs SET used = used + 1
       WHERE utc_day = ?1 AND used < ${STORY_DAY_LIMIT} AND ${run} AND NOT ${step}`
    ).bind(day, runId, attempt),
    env.DB.prepare(
      `INSERT INTO story_run_steps (run_id, role, attempt, model_id, outcome, started_at)
       SELECT run_id, 'picture', ?3, picture_model, 'running', ?4 FROM story_runs WHERE run_id = ?2 AND changes() = 1`
    ).bind(day, runId, attempt, now.toISOString()),
    env.DB.prepare(`SELECT ${run} AS run_found, ${step} AS step_found`).bind(day, runId, attempt),
  ]);
  if (taken.meta.changes === 1) return { outcome: "taken" };
  const found = (state.results as { run_found: number; step_found: number }[])[0];
  if (found.run_found !== 1) return { outcome: "refused", reason: "unknown_run" };
  return found.step_found === 1 ? { outcome: "existing" } : { outcome: "refused", reason: "day" };
}
