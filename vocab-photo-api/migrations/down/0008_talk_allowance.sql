-- Reverts 0008_talk_allowance (learn-redesign). Kept out of the top-level migrations folder so
-- `wrangler d1 migrations apply` never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/0008_talk_allowance.sql
-- The last statement forgets the migration so `migrations apply` can re-run it.

DROP TABLE IF EXISTS all_learn_talks;

DELETE FROM d1_migrations WHERE name = '0008_talk_allowance.sql';
