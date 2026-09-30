import type { Env } from "../env";
import { logEvent } from "../log";
import { windowStart } from "../subtitles/allowance";

/**
 * The daily clean-up (sad §7, ADR-0003): deletes every session past its
 * `expires_at` with its rows (tombstones included), photo slots and page
 * autofill counters. An expired session already reads as gone (AC-32), so a
 * missed run only delays the clean-up. The all-pages counter is not tied to a
 * session and stays. Photo bytes in R2 age out through the bucket's lifecycle
 * rule (README), not here.
 *
 * One batch is one transaction, and every statement picks the same sessions
 * by the same `?1`, so a session is never left half-deleted. The children are
 * deleted by name rather than through `ON DELETE CASCADE`, so the counts can
 * be logged and nothing depends on D1's foreign-key setting.
 *
 * The same run deletes every subtitle import window that started before the
 * current one (words-from-subtitles, data-model.md), so a hashed address never
 * lives a day; the day totals hold no address and stay.
 */

const EXPIRED = `SELECT id FROM sessions WHERE expires_at < ?1`;

export interface CleanupCounts {
  sessions: number;
  rows: number;
  sources: number;
  counters: number;
  subtitleWindows: number;
}

export async function deleteExpiredSessions(env: Env, now = new Date()): Promise<CleanupCounts> {
  const cutoff = now.toISOString();
  const [rows, sources, counters, sessions, subtitleWindows] = await env.DB.batch([
    env.DB.prepare(`DELETE FROM rows WHERE session_id IN (${EXPIRED})`).bind(cutoff),
    env.DB.prepare(`DELETE FROM sources WHERE session_id IN (${EXPIRED})`).bind(cutoff),
    env.DB.prepare(`DELETE FROM page_autofill WHERE session_id IN (${EXPIRED})`).bind(cutoff),
    env.DB.prepare(`DELETE FROM sessions WHERE expires_at < ?1`).bind(cutoff),
    env.DB.prepare(`DELETE FROM subtitle_imports WHERE window_start < ?1`).bind(windowStart(now)),
  ]);
  const counts = {
    sessions: sessions.meta.changes,
    rows: rows.meta.changes,
    sources: sources.meta.changes,
    counters: counters.meta.changes,
    subtitleWindows: subtitleWindows.meta.changes,
  };
  logEvent("expired sessions deleted", { ...counts });
  return counts;
}
