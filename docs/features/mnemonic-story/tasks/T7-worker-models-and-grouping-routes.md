---
id: T7
title: "Serve the offered AI list and the grouping split from the Worker"
layer: "ports"
deps: ["T2", "T4"]
acs: ["AC-03", "AC-04", "AC-12"]
files_hint: ["vocab-photo-api/src/story/grouping.ts", "vocab-photo-api/src/story/routes.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/story-grouping.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T7 — Serve the offered AI list and the grouping split from the Worker

## Why

[ADR-0004](../adr/0004-serve-the-offered-ai-list-with-prices-from-the-worker.md), [ADR-0005](../adr/0005-let-the-app-own-the-grouping-rules-and-the-ai-only-split-words.md); [sad §6](../sad.md) S-01, S-06.

## What

- The models route (`public: false`) returns `models.json` without internal fields.
- The grouping route (`public: false`) takes `{words: [{rowId, word}], keep: [{id, name, rowIds}]}`, asks Haiku 4.5 through `writeText` for topical groups of 7 to 19 with short names (only adding words to `keep` groups), parses the JSON and returns it unchanged. It is not counted against the allowance.
- Both are registered in `ROUTES` in `index.ts`.

## Definition of Done

**Done when:** Both routes answer 401 without `x-app-secret`, the models route returns the offered list with the defaults, and the grouping route returns the stub AI's groups and answers a clean error when the AI fails or returns broken JSON, all in `story-grouping.test.mjs`.

- [ ] grouping request validation (empty list, too many words, malformed body)
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- The app validates the split (T11), not this route (ADR-0005).
- Shares `routes.ts` / `index.ts` with T9 (serialized).
