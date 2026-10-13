---
id: T1
title: "Add scene-run columns and the published-dialogue tables to D1"
layer: "migration"
deps: []
acs: ["AC-10", "AC-14", "AC-20"]
files_hint: ["docs/features/get-words-from-subtitles-improvment/migrations/01_film_dialogues.up.sql", "docs/features/get-words-from-subtitles-improvment/migrations/01_film_dialogues.down.sql", "vocab-photo-api/migrations/0005_film_dialogues.sql", "vocab-photo-api/migrations/down/0005_film_dialogues.sql"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Add scene-run columns and the published-dialogue tables to D1

## Why

[sad §4](../sad.md) choices 4–5, [sad §7](../sad.md), [ADR-0004](../adr/0004-draw-scene-pictures-as-two-step-runs-of-the-story-run-workflow.md), [ADR-0005](../adr/0005-add-an-imports-rows-and-dialogues-to-the-published-session-automatically.md). No `data-model.md` exists, so the schema comes from the SAD.

## What

- Staged `01_film_dialogues.up.sql` / `.down.sql`, promoted to `vocab-photo-api/migrations/0005_film_dialogues.sql` and `migrations/down/`, in the style of `0004_story_runs.sql`.
- `story_runs` gains `kind TEXT NOT NULL DEFAULT 'story' CHECK (kind IN ('story','scene'))` and `scene_text TEXT` (a scene run stores `''` in `story_model`, ADR-0004).
- `dialogues(session_id → sessions ON DELETE CASCADE, id, position, lines_json, import_id, added_rev, picture_media_type, picture_bytes, picture_arrived_rev, PRIMARY KEY (session_id, id))`, with an index on `(session_id, added_rev)` for the change feed.
- `dialogue_words(session_id, dialogue_id, row_id, PRIMARY KEY (session_id, dialogue_id, row_id))`, cascading with the session and the dialogue.
- `dialogue_imports(session_id, import_id, PRIMARY KEY (session_id, import_id))`, which makes an append idempotent (ADR-0005).

## Definition of Done

**Done when:** `0005_film_dialogues.sql` adds the two `story_runs` columns and the three dialogue tables, applies on the `npm test` SQLite D1 stand-in, existing story runs read as `kind = 'story'`, and the down file reverts it.

- [ ] the staged pair is promoted to `vocab-photo-api/migrations/`, applies and reverts cleanly on a fresh local D1
- [ ] a test deletes a session and finds its dialogues, dialogue words and import ids gone
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Migration tasks are serialized by `implement`.
- If `/sdd:data-model` runs first, use its staged files and keep this DoD.
