---
id: T6
title: "Save cells with a per-cell revision check and limits"
layer: "ports"
deps: ["T4"]
acs: ["AC-09", "AC-10", "AC-11", "AC-33", "AC-34", "AC-38"]
files_hint: ["vocab-photo-api/src/session/edit.ts", "vocab-photo-api/src/session/types.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/edit.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T6 — Save cells with a per-cell revision check and limits

## Why

[ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md), [sad §6 flow 1 + §8](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-09](../../../features/good-looking-web/spec.md), [AC-10](../../../features/good-looking-web/spec.md), [AC-11](../../../features/good-looking-web/spec.md), [AC-33](../../../features/good-looking-web/spec.md), [AC-34](../../../features/good-looking-web/spec.md), [AC-38](../../../features/good-looking-web/spec.md).

## What

Public route: save one cell `{rowId, field, value, baseRev}` (no batch route — sad §8). The cell applies only if its `*_rev` still equals `baseRev`, in one D1 transaction that bumps the session revision; a mismatch returns `code: conflict` with the saved value and revision. Field > 500 chars → `field_too_long` with the overflow; a write that would pass 256 KB → `list_full`. Values stored as given (no HTML stripping — escaping happens on output). `sourceId` of a row is never changed by a save (AC-34). Error body `{error, code}` per sad §8.

## Definition of Done

- [x] node test: two saves from the same base revision → first lands, second gets `conflict` with the first value (AC-11)
- [x] node test: saves to different cells of the same row both land (AC-12 precondition)
- [x] node test: 501 chars → `field_too_long` naming the overflow; 256 KB + 1 → `list_full` (AC-10, AC-38)
- [x] node test: a save to a deleted row answers `conflict`; a save to an unknown row id is refused
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Same lane as T7–T9 (`edit.ts`, `index.ts`).

Route: `POST /s/<id>/cells` → `200 {rowId, field, rev}`. Status codes (fixed here, as the
`api` stage was not run): `409 conflict` (with `value`/`rev`, or `deleted: true`),
`422 field_too_long` / `list_full`, `404 unknown_row` / `gone`, `400 bad_request`. The
256 KB is counted as UTF-8 bytes of every live cell (`length(CAST(… AS BLOB))`), checked
inside the same conditional UPDATE as the revision, so no race can pass it; an edit that
shortens a cell always lands. `writeCell` also takes an "only if still empty" guard for
T9's autofill. `flutter analyze` reports the same 9 pre-existing infos; the grep's one hit
(`PhotoScaler.instance`) is pre-existing — no Dart was touched.
