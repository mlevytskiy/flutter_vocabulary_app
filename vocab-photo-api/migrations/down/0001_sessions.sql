-- Reverts 0001_sessions (good-looking-web T3). Promoted to
-- vocab-photo-api/migrations/down/0001_sessions.sql — kept out of the top-level
-- migrations folder so `wrangler d1 migrations apply` never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/0001_sessions.sql
-- The last statement forgets the migration so `migrations apply` can re-run it.

DROP TABLE IF EXISTS all_pages_autofill;
DROP TABLE IF EXISTS page_autofill;
DROP INDEX IF EXISTS sources_arrived_idx;
DROP TABLE IF EXISTS sources;
DROP INDEX IF EXISTS rows_position_idx;
DROP INDEX IF EXISTS rows_changed_idx;
DROP TABLE IF EXISTS rows;
DROP INDEX IF EXISTS sessions_expires_at_idx;
DROP TABLE IF EXISTS sessions;

DELETE FROM d1_migrations WHERE name = '0001_sessions.sql';
