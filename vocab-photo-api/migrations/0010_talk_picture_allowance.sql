-- talk-mission: the talk picture allowance (owner, 2026-10-24).
-- Revert with vocab-photo-api/migrations/down/0010_talk_picture_allowance.sql.
--
-- Counts across the whole app for one UTC day ('YYYY-MM-DD'), like all_learn_talks, and separate
-- from it. It holds no address, so it is not cleaned up. The limit is a constant in
-- src/learn/allowance.ts.

-- Talk mission pictures (POST /learn/talk/picture): one unit per call, taken before the picture
-- call and never given back. Limit 20 a day.
CREATE TABLE IF NOT EXISTS all_learn_talk_pictures (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);
