---
id: T8
title: "Serve the change feed since a revision"
layer: "ports"
deps: ["T7"]
acs: ["AC-12", "AC-37"]
files_hint: ["vocab-photo-api/src/session/edit.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/changes.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T8 — Serve the change feed since a revision

## Why

[ADR-0005](../../../features/good-looking-web/adr/0005-poll-for-changes-since-the-last-seen-revision.md). Acceptance criteria: [AC-12](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Public read `changes since N`: cells changed after N (row id, field, value, rev), rows added after N, tombstones after N, photo slots arrived after N, and the current revision. A cursor below the session's last "replaced at revision R" (a republish, ADR-0008) returns `reload: true`; the revision never goes back. Gone for unknown/expired ids.

## Definition of Done

- [ ] node test: save then poll from the old revision returns exactly that cell; poll from the new revision returns nothing
- [ ] node test: delete appears as a tombstone; photo arrival appears as an arrived slot (AC-37)
- [ ] node test: after a republish the feed answers `reload: true`
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
