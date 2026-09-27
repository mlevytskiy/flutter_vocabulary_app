---
id: T8
title: "Serve the change feed since a revision"
layer: "ports"
deps: ["T7"]
acs: ["AC-12", "AC-37"]
files_hint: ["vocab-photo-api/src/session/edit.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/changes.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T8 — Serve the change feed since a revision

## Why

[ADR-0005](../../../features/good-looking-web/adr/0005-poll-for-changes-since-the-last-seen-revision.md). Acceptance criteria: [AC-12](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Public read `changes since N`: cells changed after N (row id, field, value, rev), rows added after N, tombstones after N, photo slots arrived after N, and the current revision. A cursor below the session's last "replaced at revision R" (a republish, ADR-0008) returns `reload: true`; the revision never goes back. Gone for unknown/expired ids.

## Definition of Done

- [x] node test: save then poll from the old revision returns exactly that cell; poll from the new revision returns nothing
- [x] node test: delete appears as a tombstone; photo arrival appears as an arrived slot (AC-37)
- [x] node test: after a republish the feed answers `reload: true`
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Route: `GET /s/<id>/changes?since=N` in its own `src/session/changes.ts` (a read, so not in
`edit.ts`); public and without the page write limit. Answer:
`{rev, cells, rows, deleted, sources}` or `{rev, reload: true}`. The session, rows and sources
are read in one D1 batch, the rows with the exact `rows_changed_idx` expression.

A new row is told apart without a stored "added at" revision: every add (page, publish,
republish, KV import) stamps all three cells with one revision, so a row with all three cell
revisions above N goes out whole under `rows` — this also covers a row added after N and
edited since. An old row whose three cells were all edited after N is sent whole too, which
the page applies the same way (by row id). `reload` is also the answer for a cursor ahead of
the session's revision (not from this list). A link still only in KV is imported by the poll,
as by the page. `flutter analyze`: same 9 pre-existing infos; the grep's one hit
(`PhotoScaler.instance`) is pre-existing.
