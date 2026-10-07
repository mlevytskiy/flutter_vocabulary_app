---
id: T6
title: "Add the story allowance take and the run store to the Worker"
layer: "infra"
deps: ["T1"]
acs: ["AC-10", "AC-15", "AC-19"]
files_hint: ["vocab-photo-api/src/story/allowance.ts", "vocab-photo-api/src/story/store.ts", "vocab-photo-api/test/story-allowance.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T6 — Add the story allowance take and the run store to the Worker

## Why

[sad §4](../sad.md) "Story allowance"; [sad §8](../sad.md) "Spending control"; [ADR-0002](../adr/0002-run-each-story-run-as-a-cloudflare-workflow.md); [spec AC-19](../spec.md).

## What

- `takeStoryRun(env, runId)` and `takeDrawAgain(env, runId, attempt)`, modelled on `takeSubtitleImport`: one D1 batch, the day count raised only below 20, no address window, never given back. A start whose `run_id` already exists takes nothing.
- `store.ts`: `createRun`, `recordStep`, `runStatus(runIds[])`, `findCountedRun`, `putPicture` / `getPicture` / `deletePicture` in R2 `SOURCES` under `story-runs/<runId>/<attempt>`, and `deleteOldPictures(now)` for pictures older than 7 days.

## Definition of Done

**Done when:** 20 starts on one UTC day are taken and the 21st is refused, a repeated run id takes nothing, a Draw again takes one unit, and the store round-trips runs, steps and R2 pictures, all in `story-allowance.test.mjs`.

- [ ] race: two takes for the last unit, only one succeeds
- [ ] UTC day rollover resets the count
- [ ] `deleteOldPictures` removes only pictures older than 7 days and keeps every row
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Spec §6 "a test that the 21st of a day is refused" lives here.
