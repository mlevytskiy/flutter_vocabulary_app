---
id: T7
title: "Add and delete rows, and rate-limit page writes"
layer: "ports"
deps: ["T6"]
acs: ["AC-13", "AC-14", "AC-15", "AC-15b", "AC-35"]
files_hint: ["vocab-photo-api/src/session/edit.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/wrangler.jsonc", "vocab-photo-api/test/rows.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T7 — Add and delete rows, and rate-limit page writes

## Why

[ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md) (client ids, delete with three revisions), [sad §8](../../../features/good-looking-web/sad.md) write rate limit. Acceptance criteria: [AC-13](../../../features/good-looking-web/spec.md), [AC-14](../../../features/good-looking-web/spec.md), [AC-15](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-35](../../../features/good-looking-web/spec.md).

## What

Add row: `{rowId, field, value}` inserts a row at the end with the client's id when its first cell gets text; row 501 → `rows_full` naming 500. Delete row: `{rowId, revs: {word, translation, definition}}` sets `deleted_at_rev` only if all three still match, else `conflict` (AC-15b). New `PAGE_WRITE_LIMITER` binding (300 / 60 s per IP) on save, add, delete and define; polling and reads are not limited.

## Definition of Done

- [ ] node test: add then save — row persists; a row never given text does not exist after reload (AC-13)
- [ ] node test: 501st row refused with the limit named (AC-14)
- [ ] node test: delete after a concurrent save to that row is refused; untouched delete applies (AC-15, AC-15b)
- [ ] node test: a scripted 15-minute two-client session from one IP, with one 500-cell column autofill paced at 3 saves/s, sees no 429 (AC-35)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
