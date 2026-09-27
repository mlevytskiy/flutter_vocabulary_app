---
id: T13
title: "Add rows with the plus button and delete rows with a 5-second Undo"
layer: "ui"
deps: ["T7", "T12"]
acs: ["AC-13", "AC-14", "AC-15", "AC-15b", "AC-31"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T13 — Add rows with the plus button and delete rows with a 5-second Undo

## Why

[ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md) client-side Undo; [ux-flows US-06, US-07](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-13](../../../features/good-looking-web/spec.md), [AC-14](../../../features/good-looking-web/spec.md), [AC-15](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-31](../../../features/good-looking-web/spec.md).

## What

Plus adds an empty row at the end with the cursor in Word and a fresh UUID; the first text saves it through the add route; `rows_full` shows the limit. Delete hides the row and shows Undo for 5 s; Undo restores it in place with its photo link; after 5 s the delete is sent with the three revisions; `conflict` restores the row with the other partner's change and a "changed meanwhile" notice. Closing the page within 5 s sends nothing. Saved rows with an empty word get the needs-a-word mark.

## Definition of Done

- [x] Manual: add + type + reload keeps the row; add without text + reload → gone (AC-13)
- [x] Manual: delete, Undo within 5 s → row back in place; close tab within 5 s → row still there for others (AC-15)
- [x] Manual with two browsers: delete in A while B saves the row → row stays, A is told (AC-15b)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

`page.ts` renders a × delete button in each row's number cell, a `<template id="blank-row">`,
the "+ Add a word" button under the table, `data-max-rows` on `<main>` and an `aria-live`
`.toasts` box; all of these are hidden without the script. The × is at least 24×24 px.

`client/page.js`: a row has a `phase`: `new` (from the plus button, only in this page), `adding`
(its first save is in flight) or `live`. Plus clones the template with a fresh UUID at the end
and focuses its Word. A second tap goes back to an empty added row that is still there. With
500 stored rows, plus shows "The list is full…" instead. The first cell with text sends
`POST /rows`; all three cells take the returned revision, and cells edited meanwhile save after
it. A refusal (`rows_full`, too long, no connection) leaves the row `new` and marks the cell not
saved with the reason. An added row that never got text is simply not stored.

Delete adds `pending-delete` (hidden in place, so Undo brings it back where it was with its
`data-source`) and a "Row deleted: word · translation · definition  Undo" toast naming the row
on one line: empty fields left out, each at most 8 words (then "…"), the line cut with "…" at
`max-width: 20rem`. Each delete has its own 5-second timer. When the
timer runs out, the delete waits for any save of that row still in flight and then sends the
three revisions. A `new` row is dropped without a request. `200` / `unknown_row` removes the row.
`409` brings it back with the other partner's text (idle cells take it; a cell with unsaved text
gets the conflict choice), a brief highlight and "Someone changed this row meanwhile, so it was
not deleted."; `gone` shows the banner. Nothing is sent before the timer ends, so closing the tab
deletes nothing, and a pending delete does not trigger `beforeunload`. The needs-a-word mark is
set only from saved values, so a fresh empty row has none; a row saved with only a translation
gets it.

Checked in two isolated headless Chrome contexts over CDP against `wrangler dev` (a temporary
script, not committed). Add + word + translation, then reload: the row stayed, stored at the end
with both values. Add without text, then reload: gone. Delete + Undo: the row was back in place,
focus on its ×, and nothing was sent after 5 s. Delete + navigating away: the row was still stored.
A delete that ran out: stored as deleted and removed from the page. A deletes while B saves the
same row: the row stayed, A showed B's text, the highlight and the notice, and A's next delete
went through. At 500 rows, plus showed the limit and added nothing. No sideways scroll at
360/1280 px, and no script exception or CSP report.
