---
id: T11
title: "Render the two-layout table, photo markup and CSP on the server"
layer: "ui"
deps: ["T4"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-08", "AC-21", "AC-22", "AC-24", "AC-26", "AC-31", "AC-33", "AC-36"]
files_hint: ["vocab-photo-api/src/session/page.ts", "vocab-photo-api/src/http.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/page.test.mjs"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T11 — Render the two-layout table, photo markup and CSP on the server

## Why

[ADR-0002](../../../features/good-looking-web/adr/0002-render-the-table-on-the-server-and-enhance-it-with-plain-javascript.md); [ux-flows SCR-04, SCR-05, SCR-07](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-01](../../../features/good-looking-web/spec.md), [AC-02](../../../features/good-looking-web/spec.md), [AC-03](../../../features/good-looking-web/spec.md), [AC-04](../../../features/good-looking-web/spec.md), [AC-08](../../../features/good-looking-web/spec.md), [AC-21](../../../features/good-looking-web/spec.md), [AC-22](../../../features/good-looking-web/spec.md), [AC-24](../../../features/good-looking-web/spec.md), [AC-26](../../../features/good-looking-web/spec.md), [AC-31](../../../features/good-looking-web/spec.md), [AC-33](../../../features/good-looking-web/spec.md), [AC-36](../../../features/good-looking-web/spec.md).

## What

SSR table: row number, Word, Translation, Definition; columns chosen from the data (all-empty column → a narrow "add" control); each column capped by a CSS custom property max width, text wraps, definitions keep their line break. Wide layout (table beside a sticky photo area) and phone layout (table scrolls both ways inside its own container, page never scrolls sideways at 360 px) switch by a media query only. Photo pager markup and phone stacked/single-thumbnail button from the declared slots; pending slots render as placeholders; no photos → no photo area or button. Rows with an empty word carry the "not in the download — needs a word" mark. CSP header per sad §8; a `<script>` tag to the versioned script route (the route serves an empty module until T12).

## Definition of Done

- [ ] node test: HTML escapes `<script>` in a cell (AC-33) and sends the CSP header
- [ ] node test: a translation-only session renders Definition as the add control; a both-filled session renders all three (AC-21, AC-22)
- [ ] Visual check on `wrangler dev` at 360, 390, 414 px and 1280 px with a 100-row session: no page-level sideways scroll; long text wraps (AC-02, AC-03, AC-04)
- [ ] No photo area/button for a photo-less session (AC-08, AC-24)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Spec OQ-5 (breakpoint, column max widths) is still open and `screens` was skipped: use provisional values as CSS custom properties, and have the owner confirm them on `wrangler dev` before this task is done.
