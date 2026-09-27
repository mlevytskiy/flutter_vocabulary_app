---
id: T19
title: "Add the include-photos switch and the republish warning to the share sheet"
layer: "ui"
deps: ["T18"]
acs: ["AC-23", "AC-24", "AC-37"]
files_hint: ["lib/features/words_table/words_table_screen.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T19 — Add the include-photos switch and the republish warning to the share sheet

## Why

[ux-flows US-11, SCR-02, SCR-03](../../../features/good-looking-web/ux-flows.md); [ADR-0008](../../../features/good-looking-web/adr/0008-overwrite-the-same-link-when-a-session-is-republished.md). Acceptance criteria: [AC-23](../../../features/good-looking-web/spec.md), [AC-24](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

In the existing link option of the share bottom sheet: an "include photos (N)" switch, on by default, N = photos with ≥1 linked row, with the note that included photos are visible to anyone with the link for 30 days; hidden when N = 0. When the session was published before, a line warns that republishing replaces the edits on the shared page. The link dialog opens as soon as publish returns; uploads continue in the background.

## Definition of Done

- [ ] Widget test: switch shows with N and the 30-day note when photos exist, hidden otherwise (AC-23)
- [ ] On device: publish with 3 photos on a slow network → link dialog ≤ 3 s, photos appear on the page later (AC-37)
- [ ] Existing share-sheet file option unchanged; `flutter analyze` adds no issue
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
