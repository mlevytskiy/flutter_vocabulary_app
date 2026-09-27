---
id: T12
title: "Edit cells in place with save-on-leave, saved/not-saved states and conflict choice"
layer: "ui"
deps: ["T6", "T11"]
acs: ["AC-09", "AC-10", "AC-11", "AC-33", "AC-36", "AC-38"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/tsconfig.json", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "L"
status: "done"
---

# T12 — Edit cells in place with save-on-leave, saved/not-saved states and conflict choice

## Why

[ADR-0002](../../../features/good-looking-web/adr/0002-render-the-table-on-the-server-and-enhance-it-with-plain-javascript.md), [ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md), [ux-flows US-05](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-09](../../../features/good-looking-web/spec.md), [AC-10](../../../features/good-looking-web/spec.md), [AC-11](../../../features/good-looking-web/spec.md), [AC-33](../../../features/good-looking-web/spec.md), [AC-36](../../../features/good-looking-web/spec.md), [AC-38](../../../features/good-looking-web/spec.md).

## What

The browser script (JSDoc types, `checkJs` on): one state object holding each cell's value and revision; cells become editable in place; leaving a cell saves it; brief "saved"; on `field_too_long`/`list_full` the text stays marked not saved with the plain-words reason; on `conflict` the cell shows both values and the partner picks one (picking saves at the returned revision). Text written only via `textContent`. Resizing across the breakpoint keeps focus and typed text (no re-render).

## Definition of Done

- [x] `npm run typecheck` checks the script
- [x] Manual in two browsers on `wrangler dev`: same-cell edits produce the choice; different cells both stay (AC-11, AC-12 with reload)
- [x] Manual: 501 chars stays unsaved with the overflow shown (AC-10); markup shows as text (AC-33)
- [x] Manual: rotating/resizing while typing keeps the text (AC-36)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

All client tasks share `client/page.js` — one lane (T12→T13→T14→T15/T16).

`src/session/client/page.js`: one `state` object (`session`, highest seen `rev` for T14, `rows`
by id; each cell holds its element, saved value, revision, status). Server-rendered rows are
adopted as they are, nothing re-rendered, so a resize keeps focus and text (AC-36). Cells get
`contenteditable="plaintext-only"` (falling back to `true` plus a plain-text paste handler),
`role="textbox"` and a label. Leaving a cell (`focusout`) saves it with its `baseRev`; the tab
being hidden saves the focused cell too (`keepalive` fetch). Enter finishes a word or translation;
in a definition it is the line break. Text is read with `innerText` and put back as one text node,
and written only through `textContent`.

States on `td[data-state]` with a `.cell-note` (`aria-live`) under the text: `saving`; `saved`
for 2 s; `unsaved` with the Worker's `error` (field too long with the overflow, list full, row
deleted, write limit) or "no connection", retried on the next leave or when the browser comes
back online; `conflict` shows the other saved value with "Keep mine" (re-saves at the returned
revision) and "Use theirs". A conflict whose other value equals the typed one counts as saved.
A save while one is in flight is sent after it. `404 gone` puts up a banner and makes every
cell read-only. `beforeunload` warns while any cell holds unsaved text. A saved blank word
toggles the needs-a-word mark (AC-31).

Checked in two isolated headless Chrome contexts over CDP against `wrangler dev` (a temporary
script, not committed; needs a local Chrome): same-cell edits produced the choice, both "Keep mine"
and "Use theirs" ended saved; different cells in the two browsers both stayed after a reload; 501
characters stayed with "The translation is 1 character too long (at most 500)", `beforeunload`
warned, and deleting one character saved it; `<img onerror>`/`<b>` typed into a word showed as text
in the other browser and ran nothing; Enter in a definition saved `definition…\nexample…`;
resizing 1280→390→1280 px while typing kept focus and text. No script exception.
