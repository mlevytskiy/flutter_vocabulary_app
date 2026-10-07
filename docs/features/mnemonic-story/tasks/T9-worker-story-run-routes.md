---
id: T9
title: "Add the start, status, redo and picture routes and the 7-day picture clean-up"
layer: "ports"
deps: ["T7", "T8"]
acs: ["AC-06", "AC-09", "AC-10", "AC-13", "AC-18", "AC-19"]
files_hint: ["vocab-photo-api/src/story/routes.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/story-routes.test.mjs", "vocab-photo-api/README.md"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T9 — Add the start, status, redo and picture routes and the 7-day picture clean-up

## Why

[sad §6](../sad.md) S-02, S-04, S-05, S-09; [sad §8](../sad.md) "Authentication" and "Spending control"; [ADR-0001](../adr/0001-change-the-app-and-the-worker-as-two-surfaces.md).

## What

- Start: check the three AIs with `isOffered`, `takeStoryRun`, `createRun`, then create the Workflow (id = run id). Return started, or refused with a code (`not_offered` / `day_limit`).
- Status for several run ids in one call. Redo `{runId, step: 'prompt'|'picture', pictureModel?}`: accepted only for a counted run whose step failed; a picture redo takes `takeDrawAgain`. Picture bytes for a run attempt.
- R2-needing routes answer 503 when `SOURCES` is unbound. `scheduled()` also calls `deleteOldPictures`.
- README: the story routes, secrets and Workflow binding.

## Definition of Done

**Done when:** Every story route answers 401 without the secret; start refuses an unlisted AI and the 21st unit, and is free on a repeated run id; status returns several runs' steps; redo refuses unknown, uncounted or not-failed steps and takes a unit only for Draw again; and the web learn page and its coming-soon link answer exactly as before, all in `story-routes.test.mjs`.

- [ ] AC-18: no public route starts a run or a redo
- [ ] the cron run deletes only pictures older than 7 days
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Shares `routes.ts` / `index.ts` with T7 (serialized).
