-- learn-redesign openai-voice: the speech allowance (spec AC-31; ADR-0009 amendment, sad §5.2).
-- Revert with vocab-photo-api/migrations/down/0009_speech_allowance.sql.
--
-- Counts across the whole app for one UTC day ('YYYY-MM-DD'), like all_learn_talks, and separate
-- from it: a speech unit never uses a talk, exercise or story unit. It holds no address, so it is
-- not cleaned up. The limit is a constant in src/learn/allowance.ts.

-- Spoken AI lines (POST /learn/speech): one unit per call, taken before the OpenAI call and never
-- given back. Limit 400 a day.
CREATE TABLE IF NOT EXISTS all_learn_speech (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);
