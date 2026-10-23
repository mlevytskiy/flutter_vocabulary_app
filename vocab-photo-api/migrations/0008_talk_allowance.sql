-- learn-redesign: the talk allowance (spec AC-24, §6 talk cost row; ADR-0007, sad §6.4).
-- Revert with vocab-photo-api/migrations/down/0008_talk_allowance.sql.
--
-- Counts across the whole app for one UTC day ('YYYY-MM-DD'), like all_learn_data and
-- all_learn_checks, and separate from them: a talk unit never uses an exercise or story unit. It
-- holds no address, so it is not cleaned up. The limit is a constant in src/learn/allowance.ts.

-- Talks (POST /learn/talk): one unit per talk start, taken before the opening call and never given
-- back; a reply inside a started talk takes none. Limit 20 a day.
CREATE TABLE IF NOT EXISTS all_learn_talks (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);
