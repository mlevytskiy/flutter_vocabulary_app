import type { Env } from "../env";

/**
 * The subtitle import allowance (words-from-subtitles ADR-0003, data-model.md).
 * Every import takes one unit from its address's fixed 10-minute window and one
 * from the UTC day's total across all addresses, or neither, before the AI call
 * (spec §6, AC-14). A unit is not given back when the AI call fails. The address
 * is stored only as its SHA-256 (spec §6.1).
 */
export const SUBTITLE_WINDOW_LIMIT = 10;
export const SUBTITLE_DAY_LIMIT = 20;
const WINDOW_MS = 10 * 60 * 1000;

export type SubtitleTake = { outcome: "taken" } | { outcome: "refused"; reason: "window" | "day" };

/** The start of the 10-minute window `now` falls in, e.g. `2026-09-30T14:10:00.000Z`. */
export function windowStart(now = new Date()): string {
  return new Date(Math.floor(now.getTime() / WINDOW_MS) * WINDOW_MS).toISOString();
}

/** Lowercase hex SHA-256 of the caller's address -- the only form it is stored in. */
export async function hashAddress(address: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(address));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Takes one import from both counters, or neither, in one D1 batch (one
 * transaction), as `takeAutofillUnit` does: the day total is raised only while
 * it and the address window are below their limits, and the window only if that
 * raise happened (`changes()` is the row count of the batch's previous
 * statement). So two imports racing for the last unit cannot both get it.
 */
export async function takeSubtitleImport(env: Pick<Env, "DB">, address: string, now = new Date()): Promise<SubtitleTake> {
  const ipHash = await hashAddress(address);
  const window = windowStart(now);
  // A window never spans two days, so its first ten characters are its UTC day.
  const day = window.slice(0, 10);
  const [, , , taken, counts] = await env.DB.batch([
    env.DB.prepare(`INSERT OR IGNORE INTO all_subtitle_imports (utc_day, used) VALUES (?1, 0)`).bind(day),
    env.DB.prepare(`INSERT OR IGNORE INTO subtitle_imports (ip_hash, window_start, used) VALUES (?1, ?2, 0)`).bind(
      ipHash,
      window
    ),
    env.DB.prepare(
      `UPDATE all_subtitle_imports SET used = used + 1
       WHERE utc_day = ?3 AND used < ${SUBTITLE_DAY_LIMIT}
         AND (SELECT used FROM subtitle_imports WHERE ip_hash = ?1 AND window_start = ?2) < ${SUBTITLE_WINDOW_LIMIT}`
    ).bind(ipHash, window, day),
    env.DB.prepare(
      `UPDATE subtitle_imports SET used = used + 1 WHERE ip_hash = ?1 AND window_start = ?2 AND changes() = 1`
    ).bind(ipHash, window),
    env.DB.prepare(`SELECT used FROM subtitle_imports WHERE ip_hash = ?1 AND window_start = ?2`).bind(ipHash, window),
  ]);
  if (taken.meta.changes === 1) return { outcome: "taken" };
  const windowUsed = (counts.results as { used: number }[])[0].used;
  return { outcome: "refused", reason: windowUsed >= SUBTITLE_WINDOW_LIMIT ? "window" : "day" };
}
