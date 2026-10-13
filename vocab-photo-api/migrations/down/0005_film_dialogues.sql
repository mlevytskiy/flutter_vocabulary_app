-- Reverts 0005_film_dialogues (get-words-from-subtitles-improvment T1). Promoted to
-- vocab-photo-api/migrations/down/0005_film_dialogues.sql — kept out of the top-level
-- migrations folder so `wrangler d1 migrations apply` never runs it. Apply with:
--   npx wrangler d1 execute DB --local --file migrations/down/0005_film_dialogues.sql
-- The last statement forgets the migration so `migrations apply` can re-run it.

DROP TABLE IF EXISTS dialogue_imports;
DROP TABLE IF EXISTS dialogue_words;
DROP INDEX IF EXISTS dialogues_added_idx;
DROP TABLE IF EXISTS dialogues;
ALTER TABLE story_runs DROP COLUMN scene_text;
ALTER TABLE story_runs DROP COLUMN kind;

DELETE FROM d1_migrations WHERE name = '0005_film_dialogues.sql';
