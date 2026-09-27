---
id: T13
title: "Add rows with the plus button and delete rows with a 5-second Undo"
layer: "ui"
deps: ["T7", "T12"]
acs: ["AC-13", "AC-14", "AC-15", "AC-15b", "AC-31"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T13 — Add rows with the plus button and delete rows with a 5-second Undo

## Why

[ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md) client-side Undo; [ux-flows US-06, US-07](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-13](../../../features/good-looking-web/spec.md), [AC-14](../../../features/good-looking-web/spec.md), [AC-15](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-31](../../../features/good-looking-web/spec.md).

## What

Plus adds an empty row at the end with the cursor in Word and a fresh UUID; the first text saves it through the add route; `rows_full` shows the limit. Delete hides the row and shows Undo for 5 s; Undo restores it in place with its photo link; after 5 s the delete is sent with the three revisions; `conflict` restores the row with the other partner's change and a "changed meanwhile" notice. Closing the page within 5 s sends nothing. Saved rows with an empty word get the needs-a-word mark.

## Definition of Done

- [ ] Manual: add + type + reload keeps the row; add without text + reload → gone (AC-13)
- [ ] Manual: delete, Undo within 5 s → row back in place; close tab within 5 s → row still there for others (AC-15)
- [ ] Manual with two browsers: delete in A while B saves the row → row stays, A is told (AC-15b)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
