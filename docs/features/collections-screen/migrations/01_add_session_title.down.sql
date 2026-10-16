-- Reverts <next>_session_title (collections-screen). Promote to
-- vocab-photo-api/migrations/down/<next>_session_title.sql — kept out of the top-level
-- migrations folder so `wrangler d1 migrations apply` never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/<next>_session_title.sql
-- Pages fall back to the "Vocabulary" heading. The last statement forgets the
-- migration so `migrations apply` can re-run it.

ALTER TABLE sessions DROP COLUMN title;

DELETE FROM d1_migrations WHERE name = '<next>_session_title.sql';
