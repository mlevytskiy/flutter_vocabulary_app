---
id: T16
title: "Show the photo pager with row highlighting and the phone photo dialog"
layer: "ui"
deps: ["T5", "T13"]
acs: ["AC-05", "AC-06", "AC-07", "AC-08", "AC-34"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "M"
status: "review"
---

# T16 — Show the photo pager with row highlighting and the phone photo dialog

## Why

[ux-flows US-03, US-04, SCR-06](../../../features/good-looking-web/ux-flows.md); [ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md). Acceptance criteria: [AC-05](../../../features/good-looking-web/spec.md), [AC-06](../../../features/good-looking-web/spec.md), [AC-07](../../../features/good-looking-web/spec.md), [AC-08](../../../features/good-looking-web/spec.md), [AC-34](../../../features/good-looking-web/spec.md).

## What

Wide layout: the pager in the right corner stays in view, swipes/arrows between photos, shows "2 of 3", highlights rows whose `sourceId` is the photo on display and scrolls to the first when none is visible; typed and page-added rows never highlight. Phone: the stacked (or single) thumbnail button opens a full-width dialog with swipe between photos and pinch zoom; closing returns to the same scroll position. No new library — pointer events and CSS transforms.

## Definition of Done

- [x] Manual with a 3-photo session: pager position, highlighting and scroll-to-first behave per AC-05; typed rows never highlight (AC-06)
- [ ] Manual on a phone: dialog swipe + zoom, close restores scroll (AC-07); one photo → single thumbnail (AC-08)
- [x] Manual: editing a highlighted row's word keeps it highlighted (AC-34)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

`page.ts` now renders the pager track focusable (`tabindex="0"`, labelled for the arrow keys).
It adds a `.pager-nav` with ‹ › buttons, hidden until the script finds more than one photo,
and, when there are photos, a `<dialog class="photo-dialog">` with ‹, "n of m" (`aria-live`),
›, ×, and an empty strip. A page without photos has none of these. `style.ts`: the track hides
its scrollbar and shows a focus ring. The dialog is full-screen black; its strip slides with
a transform (no transition while dragging or under `prefers-reduced-motion`), and the page
behind does not scroll while it is open. The row highlight (`tr.from-photo`: light blue cells
and a blue left edge, dark-mode colours too) lives only inside the 900 px media query, so the
phone layout never shows it. Unsaved and conflict cells keep their red tint.

`client/page.js`: rows get `from-photo` when their `data-source` is the photo on display. It
is set in `adoptRow`, so rows that arrive by poll get it too. A typed row, a page-added row
and a row added with + have no source and never get it. The server keeps `source_id` on
edit, so the highlight survives edits and reloads (AC-34). The pager's scroll settles after
120 ms. Then "n of m" and the disabled arrows update. If no highlighted row is on screen
(below the sticky header), the first one scrolls to the centre (wide only). The arrows and
←/→ on the focused track move one photo; a trackpad swipe uses the native scroll snap. The
phone button opens the dialog on photo 1. The dialog copies the pager's images or
placeholders; a photo that arrives while it is open replaces its placeholder. Opening saves
the window and `.table-scroll` scroll positions; closing (×, Esc) restores them, empties the
strip and returns focus to the button. Gestures use pointer events and transforms:
- a horizontal swipe past 20 % of the width, or a fast one, changes the photo, with
  resistance at the ends;
- two fingers pinch-zoom around their midpoint, from 1× up to 4×;
- one finger pans a zoomed photo, clamped to its edges;
- a double tap toggles between 1× and 2.5× at the tapped point.
With one photo, the arrows are hidden and a swipe does nothing.

Tests first: `page.test.mjs` checks the new markup with and without photos. It also checks
AC-06/AC-34 on the server: an edited recognised row keeps its `sourceId`, and typed and
page-added rows have none. That test passed from the start and guards against regressions.

Checked in headless Chrome over CDP against `wrangler dev` (a temporary script, not
committed). The 3-photo session had 60 rows, photo 2's rows were 40–45, and one photo was
missing.

At 1280×800 (light and dark):
- The pager stayed at the top right (sticky, 16 px) with ‹ disabled on photo 1, and photo 1's
  rows were highlighted.
- › showed "2 of 3" and scrolled the page to row 40.
- A wheel swipe reached photo 3 and disabled ›. ← went back and scrolled to row 40 again.
- Typed, page-added and +-added rows never highlighted.
- Editing a highlighted word to "corrected" saved it. The row stayed highlighted, also after
  a reload, and `source_id` stayed in D1.
- Resizing to 390 px removed the highlight, and 1280 px brought it back.

At 390×844 with emulated touch:
- The stacked button opened "1 of 3" full-width. Swipes reached 2 and 3 and stopped at the
  end, and a short drag snapped back.
- A pinch reached 4×, a pan stayed within the edges without changing the photo, and double
  tap gave 1× and then 2.5×.
- × restored scrollY 120, and the table's scrollTop 700 and scrollLeft 90.
- A photo uploaded while the dialog was open replaced its placeholder.
- One photo gave a single thumbnail, "1 of 1", no arrows and no swipe.
- No sideways scroll, CSP report or script exception.

During those checks, local `wrangler dev` (4.127.1) sometimes stopped mid-run ("Network
connection lost" in the ProxyController, then connection refused). Chrome's network log showed
every request from the page finished normally before the crash. The same check passed
completely in other runs, and the committed suite does not hit it. It looks like a local dev
runtime issue, not something the page sends.

`npm run typecheck` is clean; `npm test` gives 53 pass, 1 skipped. `flutter analyze` still
reports the 9 infos it had before, and the grep finds only the existing
`PhotoScaler.instance`.

Left: on a real phone, check swipe, pinch zoom and close-restores-scroll (AC-07), and the
single thumbnail (AC-08). Emulated touch in headless Chrome is not the same as a real phone.
