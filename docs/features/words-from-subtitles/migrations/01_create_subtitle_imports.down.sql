-- Reverts the words-from-subtitles allowance tables. STAGED by data-model —
-- `implement` promotes it to vocab-photo-api/migrations/down/<next>_subtitle_imports.sql,
-- kept out of the top-level migrations folder so `wrangler d1 migrations apply`
-- never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/<next>_subtitle_imports.sql
-- The last statement forgets the migration so `migrations apply` can re-run it;
-- `implement` replaces <next> with the promoted number.

DROP TABLE IF EXISTS all_subtitle_imports;
DROP INDEX IF EXISTS subtitle_imports_window_start_idx;
DROP TABLE IF EXISTS subtitle_imports;

DELETE FROM d1_migrations WHERE name = '<next>_subtitle_imports.sql';
