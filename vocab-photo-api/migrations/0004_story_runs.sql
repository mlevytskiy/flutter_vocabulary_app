-- mnemonic-story T1: the story allowance and the story run records (ADR-0002, sad §4, §7, AC-10, AC-15, AC-19).
-- Promoted to vocab-photo-api/migrations/0004_story_runs.sql; revert with
-- vocab-photo-api/migrations/down/0004_story_runs.sql.
--
-- Run and step rows are kept with no expiry (sad §1 override): the Worker holds each
-- step's result until the app collects it (AC-10) and must know a counted run and its
-- story and prompt for "Try again" and "Draw again" at any later time. Only the
-- pictures in R2 are cleaned up. Limits and the allowed model list are constants in
-- the Worker (src/story/), not in the schema.
-- Times are ISO-8601 UTC strings, as in 0001_sessions.

-- Story allowance: all story runs of one UTC day, across the whole app (spec §6:
-- <= 20 per UTC day). `utc_day` is 'YYYY-MM-DD'. Taken once when a new run starts and
-- once per Draw again, and not given back when a step fails (AC-19). Holds no
-- address, so it is not cleaned up, like all_subtitle_imports.
CREATE TABLE IF NOT EXISTS all_story_runs (
  utc_day         TEXT    PRIMARY KEY,
  used            INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0)
);

-- One counted story run. `run_id` is made by the app, so a repeated start inserts
-- the same row once and takes nothing again (S-02). `words_json` is the JSON array
-- of English words the story is about; the three model columns are the AI chosen
-- for each role when the run started.
CREATE TABLE IF NOT EXISTS story_runs (
  run_id          TEXT    PRIMARY KEY,
  created_at      TEXT    NOT NULL,
  words_json      TEXT    NOT NULL,
  story_model     TEXT    NOT NULL,
  prompt_model    TEXT    NOT NULL,
  picture_model   TEXT    NOT NULL
);

-- One attempt of one step of a run (S-03, S-05): `role` is the step, `attempt`
-- counts tries of that role from 1 (Try again, Draw again). `outcome` is 'running'
-- while the step is in progress, then 'done' or 'failed' (a paid step is never
-- retried, so a failure is recorded as it is). `text` is the story or the picture
-- prompt, `missed_words_json` the words a story left out, `picture_key` the R2 key
-- under story-runs/ while the picture is held (NULL once collected or cleaned up).
-- `price_usd` is NULL when unknown; `price_estimated` is 1 when it was estimated.
CREATE TABLE IF NOT EXISTS story_run_steps (
  run_id            TEXT    NOT NULL REFERENCES story_runs (run_id) ON DELETE CASCADE,
  role              TEXT    NOT NULL CHECK (role IN ('story', 'prompt', 'picture')),
  attempt           INTEGER NOT NULL DEFAULT 1 CHECK (attempt >= 1),
  model_id          TEXT    NOT NULL,
  outcome           TEXT    NOT NULL CHECK (outcome IN ('running', 'done', 'failed')),
  text              TEXT,
  missed_words_json TEXT,
  picture_key       TEXT,
  price_usd         REAL    CHECK (price_usd IS NULL OR price_usd >= 0),
  price_estimated   INTEGER NOT NULL DEFAULT 0 CHECK (price_estimated IN (0, 1)),
  ms                INTEGER CHECK (ms IS NULL OR ms >= 0),
  started_at        TEXT    NOT NULL,
  finished_at       TEXT,
  PRIMARY KEY (run_id, role, attempt)
);

-- A run's steps, and the daily picture clean-up's walk over them.
CREATE INDEX IF NOT EXISTS story_run_steps_run_id_idx ON story_run_steps (run_id);
