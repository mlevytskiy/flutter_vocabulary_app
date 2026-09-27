---
id: T14
title: "Poll for other partners' changes, pausing when hidden and stopping after 5 idle minutes"
layer: "ui"
deps: ["T8", "T13"]
acs: ["AC-12", "AC-15b", "AC-37"]
files_hint: ["vocab-photo-api/src/session/client/page.js"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T14 — Poll for other partners' changes, pausing when hidden and stopping after 5 idle minutes

## Why

[ADR-0005](../../../features/good-looking-web/adr/0005-poll-for-changes-since-the-last-seen-revision.md), [sad §6 idle stop](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-12](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Poll the change feed ~every 5 s while the tab is visible and the partner interacted in the last 5 minutes (tap, click, key, scroll, focus, own save/autofill). Hidden → pause; idle 5 min → stop and show "updates paused"; next interaction or becoming visible → immediate catch-up poll. Apply changed cells, new rows, tombstones and arrived photos; a change for a cell being typed in is held and becomes the AC-11 choice on save. `reload: true` reloads the table.

## Definition of Done

- [ ] Manual with two browsers: 20 edits in A each appear in B within 10 s (spec §6)
- [ ] Manual: after 5 idle minutes the network panel shows no more polls and the hint shows; one click resumes with a catch-up
- [ ] Manual: a placeholder turns into its photo when the upload lands (AC-37)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
