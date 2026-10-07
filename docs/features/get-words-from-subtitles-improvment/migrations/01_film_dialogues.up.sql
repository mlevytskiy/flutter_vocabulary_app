-- get-words-from-subtitles-improvment T1: scene runs and the published-dialogue tables
-- (ADR-0004, ADR-0005, sad §4, §7; AC-10, AC-14, AC-20).
-- Promoted to vocab-photo-api/migrations/0005_film_dialogues.sql; revert with
-- vocab-photo-api/migrations/down/0005_film_dialogues.sql.
-- Times are ISO-8601 UTC strings; revisions are the session's `rev` counter (0001_sessions).

-- A scene run is a story run with no story step (ADR-0004): `kind` tells them apart,
-- existing runs read as 'story', and a scene run stores '' in `story_model` and keeps
-- the dialogue text its picture prompt is made from in `scene_text`.
ALTER TABLE story_runs ADD COLUMN kind TEXT NOT NULL DEFAULT 'story' CHECK (kind IN ('story', 'scene'));
ALTER TABLE story_runs ADD COLUMN scene_text TEXT;

-- One dialogue of a published session. `id` is made by the app (a UUID), so it is
-- unique only within its session. `lines_json` is the JSON array of the dialogue's
-- lines. `import_id` is the app's id of the import that brought it. `added_rev` is
-- the session revision at which it was added, for the change feed. The scene picture's
-- bytes live in R2 under the session's prefix, never here: `picture_media_type` and
-- `picture_bytes` are known once they arrive, `picture_arrived_rev` is the revision
-- of the arrival (NULL while no picture), so polling pages swap in the picture.
CREATE TABLE IF NOT EXISTS dialogues (
  session_id          TEXT    NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  id                  TEXT    NOT NULL,
  position            INTEGER NOT NULL,
  lines_json          TEXT    NOT NULL,
  import_id           TEXT    NOT NULL,
  added_rev           INTEGER NOT NULL CHECK (added_rev >= 0),
  picture_media_type  TEXT,
  picture_bytes       INTEGER CHECK (picture_bytes IS NULL OR picture_bytes >= 0),
  picture_arrived_rev INTEGER,
  PRIMARY KEY (session_id, id)
);

-- Change feed: "dialogues of a session added after rev N".
CREATE INDEX IF NOT EXISTS dialogues_added_idx ON dialogues (session_id, added_rev);

-- The words of a dialogue: which rows of the session it is about. Cascades with the
-- session and with the dialogue.
CREATE TABLE IF NOT EXISTS dialogue_words (
  session_id      TEXT    NOT NULL,
  dialogue_id     TEXT    NOT NULL,
  row_id          TEXT    NOT NULL,
  PRIMARY KEY (session_id, dialogue_id, row_id),
  FOREIGN KEY (session_id, dialogue_id) REFERENCES dialogues (session_id, id) ON DELETE CASCADE
);

-- Import ids already appended to a session, so a repeated append adds nothing twice
-- (ADR-0005).
CREATE TABLE IF NOT EXISTS dialogue_imports (
  session_id      TEXT    NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  import_id       TEXT    NOT NULL,
  PRIMARY KEY (session_id, import_id)
);
