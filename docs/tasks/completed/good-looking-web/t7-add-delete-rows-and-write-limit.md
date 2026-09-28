---
id: T7
title: "Add and delete rows, and rate-limit page writes"
layer: "ports"
deps: ["T6"]
acs: ["AC-13", "AC-14", "AC-15", "AC-15b", "AC-35"]
files_hint: ["vocab-photo-api/src/session/edit.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/wrangler.jsonc", "vocab-photo-api/test/rows.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T7 — Add and delete rows, and rate-limit page writes

## Why

[ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md) (client ids, delete with three revisions), [sad §8](../../../features/good-looking-web/sad.md) write rate limit. Acceptance criteria: [AC-13](../../../features/good-looking-web/spec.md), [AC-14](../../../features/good-looking-web/spec.md), [AC-15](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-35](../../../features/good-looking-web/spec.md).

## What

Add row: `{rowId, field, value}` inserts a row at the end with the client's id when its first cell gets text; row 501 → `rows_full` naming 500. Delete row: `{rowId, revs: {word, translation, definition}}` sets `deleted_at_rev` only if all three still match, else `conflict` (AC-15b). New `PAGE_WRITE_LIMITER` binding (300 / 60 s per IP) on save, add, delete and define; polling and reads are not limited.

## Definition of Done

- [x] node test: add then save — row persists; a row never given text does not exist after reload (AC-13)
- [x] node test: 501st row refused with the limit named (AC-14)
- [x] node test: delete after a concurrent save to that row is refused; untouched delete applies (AC-15, AC-15b)
- [x] node test: a scripted 15-minute two-client session from one IP, with one 500-cell column autofill paced at 3 saves/s, sees no 429 (AC-35)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Routes: `POST /s/<id>/rows` `{rowId, field, value}` → `200 {rowId, rev}` and
`POST /s/<id>/rows/delete` `{rowId, revs}` → `200 {rowId, rev}`. The row-count, size and
"id not used yet" checks sit inside the INSERT … SELECT, and the three-revision check inside the
delete's UPDATE, so no race passes them. New codes: `422 rows_full {limit: 500}` (tombstones don't
count); a delete or add that meets a changed or taken row answers `409 conflict` with the row as
saved now (`word`, `translation`, `definition`, `revs`). A retried add or delete that already
landed answers 200 again. A new row's three cells all carry the add's revision (T8 uses this to
tell new rows apart).

Write limit: routes opt in with `pageWrite: true` in `src/routing.ts`; the check keys
`PAGE_WRITE_LIMITER` (300 / 60 s) by `cf-connecting-ip` and answers `429 rate_limited`. T9's
define route will set the same flag. Locally miniflare counts in wall-clock minute windows,
so the burst test waits for a window with 20 s left.

AC-35: `test/rows.test.mjs` runs a 65-second slice of the session (a full minute of the
3-saves/s autofill beside the other partner, the busiest stretch) on every `npm test`; the
full 15-minute run is `npm run test:long` (skipped otherwise) and passed once for this task.
`scripts/test.mjs` now takes test files as arguments. `flutter analyze`: same 9 pre-existing
infos; the grep's one hit (`PhotoScaler.instance`) is pre-existing.
