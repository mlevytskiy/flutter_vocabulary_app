import type { Env } from "../env";

/**
 * The exercise allowances (learn-kit H-02, H-03, S-18): app-wide per UTC day, separate from the
 * story allowance. A data unit is one AI call of POST /learn/data (a fully cached request takes
 * none); a check unit is one POST /learn/check. A unit is taken before the AI call and never given
 * back when the call fails (AC-24). The per-address rate limiter applies on top, as for every
 * app-only route.
 */
export const LEARN_DATA_DAY_LIMIT = 200;
export const LEARN_CHECK_DAY_LIMIT = 500;
/**
 * The talk allowance (learn-redesign AC-24, ADR-0007): one unit per talk start (POST /learn/talk
 * with kind "start"), app-wide per UTC day; a reply inside a started talk never takes one.
 */
export const LEARN_TALK_DAY_LIMIT = 20;

/**
 * Takes one unit of today's `table` while it is below `limit`, in one D1 batch, with the same
 * conditional raise as `takeStoryRun`: two calls racing for the last unit cannot both get it.
 */
async function takeUnit(env: Pick<Env, "DB">, table: string, limit: number, now: Date): Promise<boolean> {
  const day = now.toISOString().slice(0, 10);
  const [, taken] = await env.DB.batch([
    env.DB.prepare(`INSERT OR IGNORE INTO ${table} (utc_day, used) VALUES (?1, 0)`).bind(day),
    env.DB.prepare(`UPDATE ${table} SET used = used + 1 WHERE utc_day = ?1 AND used < ${limit}`).bind(day),
  ]);
  return taken.meta.changes === 1;
}

/** One unit of today's exercise data allowance; false when the day is used up (AC-27). */
export const takeLearnData = (env: Pick<Env, "DB">, now = new Date()) => takeUnit(env, "all_learn_data", LEARN_DATA_DAY_LIMIT, now);

/** One unit of today's sentence check allowance; false when the day is used up (AC-34b). */
export const takeLearnCheck = (env: Pick<Env, "DB">, now = new Date()) => takeUnit(env, "all_learn_checks", LEARN_CHECK_DAY_LIMIT, now);

/** One unit of today's talk allowance, for a talk start; false when the day is used up (AC-24). */
export const takeLearnTalk = (env: Pick<Env, "DB">, now = new Date()) => takeUnit(env, "all_learn_talks", LEARN_TALK_DAY_LIMIT, now);

/**
 * The speech allowance (learn-redesign openai-voice, AC-31): one unit per POST /learn/speech call,
 * app-wide per UTC day; past it the app speaks with the phone voice.
 */
export const LEARN_SPEECH_DAY_LIMIT = 400;

/** One unit of today's speech allowance; false when the day is used up (AC-31). */
export const takeLearnSpeech = (env: Pick<Env, "DB">, now = new Date()) => takeUnit(env, "all_learn_speech", LEARN_SPEECH_DAY_LIMIT, now);
