---
id: T21
title: "Promote the staged D1 title migration into the Worker as 0007"
layer: "migration"
deps: []
acs: ["AC-29"]
files_hint: ["docs/features/collections-screen/migrations/01_add_session_title.up.sql", "docs/features/collections-screen/migrations/01_add_session_title.down.sql", "vocab-photo-api/migrations/", "vocab-photo-api/migrations/down/"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T21 — Promote the staged D1 title migration into the Worker as 0007

## Why

[ADR-0008](../adr/0008-send-the-collection-name-as-the-shared-pages-title-in-a-nullable-column.md), [data-model.md](../data-model.md) D1 `sessions.title`.

## What

- Copy the staged up/down files, replace `<next>` with `0007`.

## Definition of Done

**Done when:** The staged pair is promoted as `vocab-photo-api/migrations/0007_session_title.sql` (+ `down/0007_session_title.sql` with `<next>` filled in), applies with `wrangler d1 migrations apply DB --local`, reverts with the down file, re-applies, and `npm test` still passes on the fresh database.

- [ ] apply → revert → re-apply locally
- [ ] `npm test` and `tsc` clean in `vocab-photo-api/`

## Notes

Worker lane, independent of the app — starts in parallel with T2. Remote apply happens at deploy (T27).
