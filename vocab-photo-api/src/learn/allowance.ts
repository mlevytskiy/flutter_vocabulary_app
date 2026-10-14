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
