---
id: T22
title: "Accept, validate and store the optional title on POST /sessions create and republish"
layer: "ports"
deps: ["T21"]
acs: ["AC-02", "AC-29", "AC-30"]
files_hint: ["vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/src/session/store.ts", "vocab-photo-api/src/session/types.ts", "vocab-photo-api/src/log.ts", "vocab-photo-api/test/publish.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T22 — Accept, validate and store the optional title on POST /sessions create and republish

## Why

[contracts/openapi.yaml](../contracts/openapi.yaml) `createSession`, [api-sync-report](../contracts/api-sync-report.md), [sad §6](../sad.md#6-runtime-view) F12.

## What

- `StoredSession.title: string | null`; validation counts `[...title].length`; no trimming.
- The create/republish log line says whether a title came.

## Definition of Done

**Done when:** Worker tests show: a create with `title: "Speaking club 12"` stores it; a republish with the edit token replaces it on the same page and link; no `title` stores NULL; an empty, only-spaces, 61-code-point or two-line title gets 400 `{error, code: "title_invalid"}` per the contract with the same cases as T3; dialogue and picture deliveries never change `title`.

- [ ] contract cases incl. emoji and Cyrillic
- [ ] `npm test` and `tsc` clean in `vocab-photo-api/`

## Notes

—
