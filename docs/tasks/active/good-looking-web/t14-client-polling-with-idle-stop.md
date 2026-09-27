---
id: T14
title: "Poll for other partners' changes, pausing when hidden and stopping after 5 idle minutes"
layer: "ui"
deps: ["T8", "T13"]
acs: ["AC-12", "AC-15b", "AC-37"]
files_hint: ["vocab-photo-api/src/session/client/page.js"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T14 — Poll for other partners' changes, pausing when hidden and stopping after 5 idle minutes

## Why

[ADR-0005](../../../features/good-looking-web/adr/0005-poll-for-changes-since-the-last-seen-revision.md), [sad §6 idle stop](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-12](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Poll the change feed ~every 5 s while the tab is visible and the partner interacted in the last 5 minutes (tap, click, key, scroll, focus, own save/autofill). Hidden → pause; idle 5 min → stop and show "updates paused"; next interaction or becoming visible → immediate catch-up poll. Apply changed cells, new rows, tombstones and arrived photos; a change for a cell being typed in is held and becomes the AC-11 choice on save. `reload: true` reloads the table.

## Definition of Done

- [x] Manual with two browsers: 20 edits in A each appear in B within 10 s (spec §6)
- [x] Manual: after 5 idle minutes the network panel shows no more polls and the hint shows; one click resumes with a catch-up
- [x] Manual: a placeholder turns into its photo when the upload lands (AC-37)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

`client/page.js` polls `GET /s/<id>/changes?since=<rev>` every 5 s (one request at a time; a
poll asked for while one is in flight runs right after it). The cursor moves only from feed
answers, never from the page's own saves: jumping it to a save's revision could skip another
partner's change with a lower revision. Using the page means pointerdown, keydown, focusin and
scroll (captured, so the phone layout's scrolling table counts), plus each own request. A
hidden tab clears the timer and saves the focused cell. After 5 minutes without use, polling
stops and a `role="status"` hint "Updates paused while you were away. Click or tap anywhere
to see the latest changes." shows under the list header. The next use, or the tab becoming
visible, removes the hint and polls at once.

Applying a feed: a changed cell that is idle takes the text and revision. A cell that is
focused, has unsaved text, is being autofilled, or is in a row whose delete is waiting for
Undo keeps the change as `held`. A held change in a cell with unsaved text becomes the AC-11
choice on its save. A held change in a clean cell is shown when the cell is left, the save
ends, Undo is pressed or the delete is refused (AC-15b: the delete then sends the old
revision and is refused). New rows are cloned from the blank-row template and placed before
the first row that is not live. Tombstones remove the row; if the partner was typing in it,
a toast says the row was deleted by someone else. An arrived photo replaces the placeholder
with `<img alt="Source photo i of n">`, and the phone layout's thumb span with its image.
Text arriving in a collapsed column opens it. `reload: true` reloads the page when nothing is
unsaved, and otherwise shows a banner asking the partner to copy their text first. `gone`
makes the page read-only.

Checked in two isolated headless Chrome contexts over CDP against `wrangler dev` (a temporary
script, not committed). 20 edits in A (translation and word cells) each appeared in B, taking
4.9–5.1 s (max 5.1 s). B typing while A saved the same cell kept B's text; on leaving, B got
the conflict choice naming A's text, and "Keep mine" reached A. A focused clean cell got A's
change on leave. A change during B's Undo kept B's row, and B's delete was refused with the
notice. Rows added and deleted in A appeared and went away in B. A placeholder became the
photo after `PUT /sources/<n>`. With the clock moved 5 min ahead, the hint showed and no poll
went out for 12 s while A edited. One real mouse click removed the hint and B showed A's edit
103 ms later. Hidden: no poll for 11 s; visible again: one poll at once. No script exception
or CSP report (Chrome's console lines for the expected 409/422/429 answers aside).
`npm run typecheck` is clean; `npm test` gives 51 pass, 1 skipped. `flutter analyze` still
reports the 9 infos it had before, and the grep finds only the existing
`PhotoScaler.instance`.
