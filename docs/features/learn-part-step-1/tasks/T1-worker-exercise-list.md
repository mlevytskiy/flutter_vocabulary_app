---
id: T1
title: "Add the exercise list and the word-to-learn rule to the Worker"
layer: "domain"
deps: []
acs: ["AC-04", "AC-08b"]
files_hint: ["vocab-photo-api/src/learn/exercises.json", "vocab-photo-api/src/learn/exercises.ts", "vocab-photo-api/test/learn-exercises.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Add the exercise list and the word-to-learn rule to the Worker

## Why

The single source of truth for the plan ([ADR-0003](../adr/0003-keep-the-exercise-list-as-json-in-the-worker-and-test-the-app-copy-against-it.md)); ids and names from [spec §AC-04](../spec.md), shape from the `Exercise` schema in [openapi.yaml](../contracts/openapi.yaml). The word-to-learn rule is [CONTEXT](../CONTEXT.md) "word to learn" = `WordPair.isFilled` ([sad §2](../sad.md), §8 "Rules shared by app and Worker").

## What

- `vocab-photo-api/src/learn/exercises.json` — the eleven entries in plan order, stable kebab-case ids (frozen from now on, sad §11 accepted debt).
- `vocab-photo-api/src/learn/exercises.ts` — typed view of the JSON (`Exercise`, `EXERCISES`, `findAvailable(id)`) and `isWordToLearn(row)` over a saved row (`word`, `translation`, `definition`, not deleted).
- `vocab-photo-api/test/learn-exercises.test.mjs`.

## Definition of Done

**Done when:** `exercises.json` holds the eleven `{id, name, stage, available}` entries in AC-04 order with only `mnemonic-story` available, `exercises.ts` exposes them typed plus `isWordToLearn(row)` with the same trim rule as `WordPair.isFilled`, and `node --test` covers order, ids, the single available entry and the word-to-learn rule.

- [ ] the list has 11 entries, stages 1/2/3 in AC-04 order, names verbatim from AC-04
- [ ] only `mnemonic-story` has `available: true`
- [ ] `isWordToLearn` is false for a blank word, for whitespace-only translation and definition, and true for word + translation or word + definition
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- No HTTP surface yet — T3 consumes this. Kept separate so the app parity test (T2) can start as soon as the JSON exists.
- Check how `tsconfig.json` handles a JSON import (`resolveJsonModule`) and how `wrangler` bundles it; follow the repo's existing pattern if one exists.
