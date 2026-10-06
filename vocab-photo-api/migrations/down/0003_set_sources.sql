-- Reverts import-from-quizlet's set sources (promoted from
-- docs/features/import-from-quizlet/migrations/01_add_set_sources.down.sql),
-- kept out of the top-level migrations folder so `wrangler d1 migrations apply`
-- never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/0003_set_sources.sql
-- The last statement forgets the migration so `migrations apply` can re-run it.
--
-- Set slots cannot exist in the old shape: rows linked to one lose the link
-- (they become typed rows on the page), then the set slots are deleted and the
-- table is rebuilt without kind, name and url. Photo slots are kept as they are.

PRAGMA defer_foreign_keys = true;

UPDATE rows SET source_id = NULL
 WHERE source_id IS NOT NULL
   AND EXISTS (SELECT 1 FROM sources s
                WHERE s.session_id = rows.session_id AND s.id = rows.source_id AND s.kind = 'set');

DELETE FROM sources WHERE kind = 'set';

CREATE TABLE IF NOT EXISTS sources_old (
  session_id      TEXT    NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  id              TEXT    NOT NULL,
  ord             INTEGER NOT NULL,
  media_type      TEXT,
  bytes           INTEGER CHECK (bytes IS NULL OR bytes >= 0),
  status          TEXT    NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'arrived')),
  arrived_rev     INTEGER,
  PRIMARY KEY (session_id, id),
  CHECK ((status = 'arrived') = (arrived_rev IS NOT NULL))
);

INSERT INTO sources_old (session_id, id, ord, media_type, bytes, status, arrived_rev)
  SELECT session_id, id, ord, media_type, bytes, status, arrived_rev FROM sources;

DROP TABLE sources;

ALTER TABLE sources_old RENAME TO sources;

CREATE INDEX IF NOT EXISTS sources_arrived_idx ON sources (session_id, arrived_rev);

DELETE FROM d1_migrations WHERE name = '0003_set_sources.sql';
