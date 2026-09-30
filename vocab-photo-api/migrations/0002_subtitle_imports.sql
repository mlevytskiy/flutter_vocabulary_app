-- words-from-subtitles: the subtitle import allowance (ADR-0003, sad §8, AC-14).
-- Promoted from docs/features/words-from-subtitles/migrations/01_create_subtitle_imports.up.sql;
-- revert with vocab-photo-api/migrations/down/0002_subtitle_imports.sql.
--
-- Two counters, taken together in one D1 batch before the AI call, the same way
-- src/autofill/meter.ts takes page_autofill + all_pages_autofill: the day total is
-- raised only while it is below 20 and the address window is below 10, and the
-- address window only if the day total was raised (`changes() = 1`). A taken unit
-- is not given back when the AI call fails. The limits are constants in
-- src/subtitles/allowance.ts, not in the schema.
-- Times are ISO-8601 UTC strings, as in 0001_sessions.

-- One app address's imports in one fixed 10-minute window (spec §6: ≤ 10 per
-- 10 minutes). `ip_hash` is the lowercase hex SHA-256 of `cf-connecting-ip` —
-- never the address itself (spec §6.1). `window_start` is the window's start,
-- floored to 10 minutes, e.g. '2026-09-30T14:10:00.000Z'. The daily clean-up
-- deletes every window that started before the current one, so no row lives a
-- day (spec §6.1 "deletes it within a day").
CREATE TABLE IF NOT EXISTS subtitle_imports (
  ip_hash         TEXT    NOT NULL CHECK (length(ip_hash) = 64),
  window_start    TEXT    NOT NULL,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0),
  PRIMARY KEY (ip_hash, window_start)
);

-- Daily clean-up: "address windows that started before the current window".
CREATE INDEX IF NOT EXISTS subtitle_imports_window_start_idx ON subtitle_imports (window_start);

-- All subtitle imports of one UTC day, from any address (spec §6: ≤ 20 per UTC
-- day). `utc_day` is 'YYYY-MM-DD'. Holds no address, so it is not cleaned up,
-- like all_pages_autofill.
CREATE TABLE IF NOT EXISTS all_subtitle_imports (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);
