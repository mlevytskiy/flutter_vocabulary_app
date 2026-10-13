-- Reverts 0004_story_runs (mnemonic-story T1). Promoted to
-- vocab-photo-api/migrations/down/0004_story_runs.sql — kept out of the top-level
-- migrations folder so `wrangler d1 migrations apply` never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/0004_story_runs.sql
-- The last statement forgets the migration so `migrations apply` can re-run it.

DROP INDEX IF EXISTS story_run_steps_run_id_idx;
DROP TABLE IF EXISTS story_run_steps;
DROP TABLE IF EXISTS story_runs;
DROP TABLE IF EXISTS all_story_runs;

DELETE FROM d1_migrations WHERE name = '0004_story_runs.sql';
