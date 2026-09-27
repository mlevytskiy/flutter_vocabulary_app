import type { Env } from "../env";

/**
 * Definition autofill metering (ADR-0003, sad §4). A lookup from a page takes
 * one unit of that page's allowance and one of the share all pages together
 * may use of the dictionary's 1,000 calls a day; the rest is kept for the
 * app's own `/define`, which is never counted (AC-29). Days are UTC.
 */
export const PAGE_AUTOFILL_LIMIT = 50;
export const ALL_PAGES_AUTOFILL_LIMIT = 500;

export type Take = { outcome: "taken" } | { outcome: "paused"; reason: "page" | "all_pages"; resumesAt: string };

export function utcDay(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

/** The start of the next UTC day, when both counters start again. */
export function nextUtcMidnight(now = new Date()): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1)).toISOString();
}

/**
 * Takes one unit from both counters, or neither, in one D1 batch (one
 * transaction): the all-pages share is raised only while both counters are
 * below their limits, and the page's allowance only if that raise happened --
 * `changes()` is the row count of the batch's previous statement. So two
 * pages racing for the last unit cannot both get it, and nothing is retried.
 */
export async function takeAutofillUnit(env: Env, sessionId: string, now = new Date()): Promise<Take> {
  const day = utcDay(now);
  const [, , , page, counts] = await env.DB.batch([
    env.DB.prepare(`INSERT OR IGNORE INTO all_pages_autofill (utc_day, used) VALUES (?1, 0)`).bind(day),
    env.DB.prepare(`INSERT OR IGNORE INTO page_autofill (session_id, utc_day, used) VALUES (?1, ?2, 0)`).bind(
      sessionId,
      day
    ),
    env.DB.prepare(
      `UPDATE all_pages_autofill SET used = used + 1
       WHERE utc_day = ?2 AND used < ${ALL_PAGES_AUTOFILL_LIMIT}
         AND (SELECT used FROM page_autofill WHERE session_id = ?1 AND utc_day = ?2) < ${PAGE_AUTOFILL_LIMIT}`
    ).bind(sessionId, day),
    env.DB.prepare(
      `UPDATE page_autofill SET used = used + 1 WHERE session_id = ?1 AND utc_day = ?2 AND changes() = 1`
    ).bind(sessionId, day),
    env.DB.prepare(`SELECT used FROM page_autofill WHERE session_id = ?1 AND utc_day = ?2`).bind(sessionId, day),
  ]);
  if (page.meta.changes === 1) return { outcome: "taken" };
  const pageUsed = (counts.results as { used: number }[])[0].used;
  // Both spent reads as the page's own limit: its partner can do nothing either way.
  const reason = pageUsed >= PAGE_AUTOFILL_LIMIT ? "page" : "all_pages";
  return { outcome: "paused", reason, resumesAt: nextUtcMidnight(now) };
}
