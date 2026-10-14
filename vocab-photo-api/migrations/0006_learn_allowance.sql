-- learn-kit: the two exercise allowances (spec §6.2, AC-27, AC-34b; decisions S-18).
-- Revert with vocab-photo-api/migrations/down/0006_learn_allowance.sql.
--
-- Both count across the whole app for one UTC day ('YYYY-MM-DD'), like all_story_runs, and are
-- separate from it: a learn unit never uses a story unit. They hold no address, so they are not
-- cleaned up. The limits are constants in src/learn/allowance.ts, not in the schema.

-- Exercise data (POST /learn/data): one unit per AI call, taken before it and never given back;
-- a request answered fully from the cache takes none. Limit 200 a day.
CREATE TABLE IF NOT EXISTS all_learn_data (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);

-- Sentence checks (POST /learn/check): one unit per check, never given back. Limit 500 a day.
CREATE TABLE IF NOT EXISTS all_learn_checks (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);
