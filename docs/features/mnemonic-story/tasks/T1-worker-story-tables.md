---
id: T1
title: "Add the story allowance, story run and step tables to D1"
layer: "migration"
deps: []
acs: ["AC-10", "AC-15", "AC-19"]
files_hint: ["docs/features/mnemonic-story/migrations/01_story_runs.up.sql", "docs/features/mnemonic-story/migrations/01_story_runs.down.sql", "vocab-photo-api/migrations/0004_story_runs.sql", "vocab-photo-api/migrations/down/0004_story_runs.sql"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Add the story allowance, story run and step tables to D1

## Why

[sad §4](../sad.md) "Story allowance", [sad §7](../sad.md), [ADR-0002](../adr/0002-run-each-story-run-as-a-cloudflare-workflow.md); [sad §6](../sad.md) S-02, S-03 and S-05 persist notes. No `data-model.md` exists (the stage was skipped), so this task writes the schema from the SAD.

## What

- Staged `docs/features/mnemonic-story/migrations/01_story_runs.up.sql` / `.down.sql`, promoted to `vocab-photo-api/migrations/0004_story_runs.sql` and `migrations/down/0004_story_runs.sql`, in the style of `0002_subtitle_imports.sql`: header comment, ISO-8601 UTC strings, `CHECK`s.
- `all_story_runs(utc_day TEXT PRIMARY KEY, used INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0))`, the day count (AC-19).
- `story_runs(run_id TEXT PRIMARY KEY, created_at, words_json, story_model, prompt_model, picture_model)`. The run id key makes a repeated start free (S-02).
- `story_run_steps(run_id, role, attempt, model_id, outcome, text, missed_words_json, picture_key, price_usd, price_estimated, ms, started_at, finished_at, PRIMARY KEY (run_id, role, attempt))`, with an index on `run_id`.
- Rows are kept with no expiry (sad §1 override). Only R2 pictures are cleaned up (T9).

## Definition of Done

**Done when:** `0004_story_runs.sql` creates `all_story_runs`, `story_runs` and `story_run_steps` with the keys above, applies on the `npm test` SQLite D1 stand-in, and its down file drops them again.

- [ ] the staged up/down pair is promoted to `vocab-photo-api/migrations/`, then applies and reverts cleanly on a fresh local D1
- [ ] a test inserts a run twice by `run_id` and gets one row
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Migration tasks are serialized by `implement`.
- If `/sdd:data-model` runs first, use its staged files instead and keep this task's DoD.
