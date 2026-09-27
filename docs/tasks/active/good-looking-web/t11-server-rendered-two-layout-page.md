---
id: T11
title: "Render the two-layout table, photo markup and CSP on the server"
layer: "ui"
deps: ["T4"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-08", "AC-21", "AC-22", "AC-24", "AC-26", "AC-31", "AC-33", "AC-36"]
files_hint: ["vocab-photo-api/src/session/page.ts", "vocab-photo-api/src/http.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/page.test.mjs"]
owner: "Maksym"
estimate: "L"
status: "done"
---

# T11 — Render the two-layout table, photo markup and CSP on the server

## Why

[ADR-0002](../../../features/good-looking-web/adr/0002-render-the-table-on-the-server-and-enhance-it-with-plain-javascript.md); [ux-flows SCR-04, SCR-05, SCR-07](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-01](../../../features/good-looking-web/spec.md), [AC-02](../../../features/good-looking-web/spec.md), [AC-03](../../../features/good-looking-web/spec.md), [AC-04](../../../features/good-looking-web/spec.md), [AC-08](../../../features/good-looking-web/spec.md), [AC-21](../../../features/good-looking-web/spec.md), [AC-22](../../../features/good-looking-web/spec.md), [AC-24](../../../features/good-looking-web/spec.md), [AC-26](../../../features/good-looking-web/spec.md), [AC-31](../../../features/good-looking-web/spec.md), [AC-33](../../../features/good-looking-web/spec.md), [AC-36](../../../features/good-looking-web/spec.md).

## What

SSR table: row number, Word, Translation, Definition; columns chosen from the data (all-empty column → a narrow "add" control); each column capped by a CSS custom property max width, text wraps, definitions keep their line break. Wide layout (table beside a sticky photo area) and phone layout (table scrolls both ways inside its own container, page never scrolls sideways at 360 px) switch by a media query only. Photo pager markup and phone stacked/single-thumbnail button from the declared slots; pending slots render as placeholders; no photos → no photo area or button. Rows with an empty word carry the "not in the download — needs a word" mark. CSP header per sad §8; a `<script>` tag to the versioned script route (the route serves an empty module until T12).

## Definition of Done

- [x] node test: HTML escapes `<script>` in a cell (AC-33) and sends the CSP header
- [x] node test: a translation-only session renders Definition as the add control; a both-filled session renders all three (AC-21, AC-22)
- [x] Visual check on `wrangler dev` at 360, 390, 414 px and 1280 px with a 100-row session: no page-level sideways scroll; long text wraps (AC-02, AC-03, AC-04)
- [x] No photo area/button for a photo-less session (AC-08, AC-24)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Spec OQ-5 (breakpoint, column max widths) is still open and `screens` was skipped: use provisional values as CSS custom properties, and have the owner confirm them on `wrangler dev` before this task is done.

**Owner check still open (OQ-5):** the provisional values are at the top of
`vocab-photo-api/src/session/style.ts` — breakpoint 900 px; wide: Word 10rem, Translation 10rem,
Definition 36rem (squeezed by the table's `max-width: 100%`), photo area `clamp(16rem, 28vw, 24rem)`;
phone: Word 6.5rem, Translation 6.5rem, Definition `min(18rem, 75vw)`. Confirm or change them on
`wrangler dev`.

Rendered from `StoredSession`, not `toDocument` (which drops pending slots and row ids). Columns
come from the data (AC-27): Translation/Definition with no text in any row collapse to a
`+ Translation`/`+ Definition` button in their `<th>` (`class="no-<field>"` on `<main>` hides
their cells' text; T15 wires the opening). Data for the script rides on attributes: `data-session`
and `data-rev` on `<main>`, `data-row`/`data-source` on `<tr>`, `data-field`/`data-rev` on `<td>`.
Cell text is in `<div class="v">` with `white-space: pre-wrap` (no more `<br>`), so a definition
keeps its line break and `textContent` round-trips. Row numbers are a CSS counter, so T13's
added/hidden rows renumber themselves. The needs-a-word mark is always in the Word cell and shown
by `tr.needs-word`.

Photos: the pager (`<aside class="photos">`, a scroll-snap track of `figure.slide`s with "N of M",
prev/next `hidden` until T16) and the phone `button.photo-button` (up to three thumbnails, `stack`
class when more than one; shown only once the script has set `html.js`, since it does nothing
without it). Both use `loading="lazy"`, so the layout that hides them does not fetch them.

CSP (`src/session/assets.ts`, also on the gone page): `default-src 'none'; script-src 'self';
style-src 'sha256-…'; img-src 'self'; connect-src 'self' https://translate.googleapis.com;
base-uri 'none'; form-action 'none'; frame-ancestors 'none'`, plus `referrer-policy: same-origin`
(the link is the write credential). The CSS stays inline for first render and is allowed by its
hash, computed on first request.

Script: `src/session/client/page.js` is bundled as a Text module (`rules` in `wrangler.jsonc`,
`page.d.ts` beside it types the import), served at `/assets/page-<first 12 hex of sha256>.js`
with `public, max-age=31536000, immutable`; any other hash is 404. `npm run typecheck` now also
runs `tsc -p tsconfig.client.json` (DOM lib, `checkJs`). In T11 the script only adds `html.js`.

Visual check: headless Chrome over CDP against `wrangler dev`, a 100-row session with three photo
slots (one pending), a 47-character word and a ~350-character definition. At 360/390/414 px the
page's `scrollWidth` equals the viewport, the table scrolls inside `.table-scroll` both ways, and
Definition starts at 292 px (68 px visible at 360); at 1280 px the table (16–882 px) sits beside
the sticky pager (906–1264 px). No `.v` wider than its max width anywhere; the long word and
definition wrap into taller rows; no CSP violation reported. Phone Word/Translation were 7rem at
first, which left only 28 px of Definition at 360 px, hence 6.5rem.

`test/page.test.mjs` (9 tests); `publish.test.mjs` matches `<div class="v">` instead of `<td>`;
`gone.test.mjs` also checks no `<script>` and the CSP.
