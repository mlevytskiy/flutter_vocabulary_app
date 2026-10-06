-- import-from-quizlet: set sources beside photo slots (ADR-0005, ADR-0006, sad §5).
-- Promoted from docs/features/import-from-quizlet/migrations/01_add_set_sources.up.sql;
-- revert with vocab-photo-api/migrations/down/0003_set_sources.sql.
--
-- A source slot is now a photo or a Quizlet set, told apart by `kind`. A set
-- slot carries the set's name and its plain link (`https://quizlet.com/<id>/<slug>/`),
-- has no bytes, and is "arrived" from the moment it is published (sad §6 F4).
-- Existing slots become `kind = 'photo'` unchanged. The link format and the
-- 500-character name limit are checked in src/session/types.ts (MAX_FIELD_CHARS),
-- not in the schema, like every other text limit.
--
-- SQLite cannot add a check across columns with ALTER TABLE, so the table is
-- rebuilt: new table, copy, drop, rename, re-create its index. Nothing refers to
-- `sources` by foreign key (`rows.source_id` is a plain column), so the drop
-- touches no other table; `defer_foreign_keys` keeps D1 from checking the
-- sessions reference mid-rebuild.

PRAGMA defer_foreign_keys = true;

CREATE TABLE IF NOT EXISTS sources_new (
  session_id      TEXT    NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  id              TEXT    NOT NULL,
  ord             INTEGER NOT NULL,
  kind            TEXT    NOT NULL DEFAULT 'photo' CHECK (kind IN ('photo', 'set')),
  name            TEXT,
  url             TEXT,
  media_type      TEXT,
  bytes           INTEGER CHECK (bytes IS NULL OR bytes >= 0),
  status          TEXT    NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'arrived')),
  arrived_rev     INTEGER,
  PRIMARY KEY (session_id, id),
  CHECK ((status = 'arrived') = (arrived_rev IS NOT NULL)),
  -- A set has a name and a link, a photo has neither.
  CHECK ((kind = 'set') = (name IS NOT NULL AND url IS NOT NULL)),
  CHECK (kind = 'set' OR (name IS NULL AND url IS NULL)),
  -- A set never has bytes and is arrived at publish.
  CHECK (kind = 'photo' OR (status = 'arrived' AND media_type IS NULL AND bytes IS NULL))
);

INSERT INTO sources_new (session_id, id, ord, kind, media_type, bytes, status, arrived_rev)
  SELECT session_id, id, ord, 'photo', media_type, bytes, status, arrived_rev FROM sources;

DROP TABLE sources;

ALTER TABLE sources_new RENAME TO sources;

-- Change feed: sources of a session that arrived after rev N (unchanged from 0001).
CREATE INDEX IF NOT EXISTS sources_arrived_idx ON sources (session_id, arrived_rev);
