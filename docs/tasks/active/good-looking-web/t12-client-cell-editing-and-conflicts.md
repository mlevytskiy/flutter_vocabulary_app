---
id: T12
title: "Edit cells in place with save-on-leave, saved/not-saved states and conflict choice"
layer: "ui"
deps: ["T6", "T11"]
acs: ["AC-09", "AC-10", "AC-11", "AC-33", "AC-36", "AC-38"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/tsconfig.json", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T12 — Edit cells in place with save-on-leave, saved/not-saved states and conflict choice

## Why

[ADR-0002](../../../features/good-looking-web/adr/0002-render-the-table-on-the-server-and-enhance-it-with-plain-javascript.md), [ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md), [ux-flows US-05](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-09](../../../features/good-looking-web/spec.md), [AC-10](../../../features/good-looking-web/spec.md), [AC-11](../../../features/good-looking-web/spec.md), [AC-33](../../../features/good-looking-web/spec.md), [AC-36](../../../features/good-looking-web/spec.md), [AC-38](../../../features/good-looking-web/spec.md).

## What

The browser script (JSDoc types, `checkJs` on): one state object holding each cell's value and revision; cells become editable in place; leaving a cell saves it; brief "saved"; on `field_too_long`/`list_full` the text stays marked not saved with the plain-words reason; on `conflict` the cell shows both values and the partner picks one (picking saves at the returned revision). Text written only via `textContent`. Resizing across the breakpoint keeps focus and typed text (no re-render).

## Definition of Done

- [ ] `npm run typecheck` checks the script
- [ ] Manual in two browsers on `wrangler dev`: same-cell edits produce the choice; different cells both stay (AC-11, AC-12 with reload)
- [ ] Manual: 501 chars stays unsaved with the overflow shown (AC-10); markup shows as text (AC-33)
- [ ] Manual: rotating/resizing while typing keeps the text (AC-36)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

All client tasks share `client/page.js` — one lane (T12→T13→T14→T15/T16).
