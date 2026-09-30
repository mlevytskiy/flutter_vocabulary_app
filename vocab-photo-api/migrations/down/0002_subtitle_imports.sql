-- Reverts 0002_subtitle_imports (words-from-subtitles). Promoted to
-- vocab-photo-api/migrations/down/0002_subtitle_imports.sql — kept out of the top-level migrations folder so `wrangler d1 migrations apply`
-- never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/0002_subtitle_imports.sql
-- The last statement forgets the migration so `migrations apply` can re-run it.

DROP TABLE IF EXISTS all_subtitle_imports;
DROP INDEX IF EXISTS subtitle_imports_window_start_idx;
DROP TABLE IF EXISTS subtitle_imports;

DELETE FROM d1_migrations WHERE name = '0002_subtitle_imports.sql';
