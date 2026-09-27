---
id: T16
title: "Show the photo pager with row highlighting and the phone photo dialog"
layer: "ui"
deps: ["T5", "T13"]
acs: ["AC-05", "AC-06", "AC-07", "AC-08", "AC-34"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T16 — Show the photo pager with row highlighting and the phone photo dialog

## Why

[ux-flows US-03, US-04, SCR-06](../../../features/good-looking-web/ux-flows.md); [ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md). Acceptance criteria: [AC-05](../../../features/good-looking-web/spec.md), [AC-06](../../../features/good-looking-web/spec.md), [AC-07](../../../features/good-looking-web/spec.md), [AC-08](../../../features/good-looking-web/spec.md), [AC-34](../../../features/good-looking-web/spec.md).

## What

Wide layout: the pager in the right corner stays in view, swipes/arrows between photos, shows "2 of 3", highlights rows whose `sourceId` is the photo on display and scrolls to the first when none is visible; typed and page-added rows never highlight. Phone: the stacked (or single) thumbnail button opens a full-width dialog with swipe between photos and pinch zoom; closing returns to the same scroll position. No new library — pointer events and CSS transforms.

## Definition of Done

- [ ] Manual with a 3-photo session: pager position, highlighting and scroll-to-first behave per AC-05; typed rows never highlight (AC-06)
- [ ] Manual on a phone: dialog swipe + zoom, close restores scroll (AC-07); one photo → single thumbnail (AC-08)
- [ ] Manual: editing a highlighted row's word keeps it highlighted (AC-34)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
