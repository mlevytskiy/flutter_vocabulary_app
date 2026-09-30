---
id: T19
title: "Add the include-photos switch and the republish warning to the share sheet"
layer: "ui"
deps: ["T18"]
acs: ["AC-23", "AC-24", "AC-37"]
files_hint: ["lib/features/words_table/words_table_screen.dart"]
owner: "Maksym"
estimate: "S"
status: "review"
---

# T19 — Add the include-photos switch and the republish warning to the share sheet

## Why

[ux-flows US-11, SCR-02, SCR-03](../../../features/good-looking-web/ux-flows.md); [ADR-0008](../../../features/good-looking-web/adr/0008-overwrite-the-same-link-when-a-session-is-republished.md). Acceptance criteria: [AC-23](../../../features/good-looking-web/spec.md), [AC-24](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

In the existing link option of the share bottom sheet: an "include photos (N)" switch, on by default, N = photos with ≥1 linked row, with the note that included photos are visible to anyone with the link for 30 days; hidden when N = 0. When the session was published before, a line warns that republishing replaces the edits on the shared page. The link dialog opens as soon as publish returns; uploads continue in the background.

## Definition of Done

- [x] Widget test: switch shows with N and the 30-day note when photos exist, hidden otherwise (AC-23)
- [ ] On device: publish with 3 photos on a slow network → link dialog ≤ 3 s, photos appear on the page later (AC-37) (manual, pending user check)
- [x] Existing share-sheet file option unchanged; `flutter analyze` adds no issue
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Only `words_table_screen.dart` changed. The share sheet is now wrapped in a
`StatefulBuilder` so it can hold the switch. The "Share file" and "Share link" tiles are
the same widgets, re-indented. Below them, a `SwitchListTile` "Include photos (N)" shows
with the subtitle "Included photos are visible to anyone with the link for 30 days.". It
is on by default. N counts the session's photos that have at least one of the filled rows
the table lists (the rows that get published). With N = 0 the switch is hidden (AC-23).
Switched on, `_shareLink` passes `session.sources` to `publish`, which declares the first
10 linked photos by taken time (T18). Switched off, or with no photos, it passes
`const []`, so no `sources` and no `sourceId` are sent (AC-24). When the session has a
`publishedId`, a line warns: "This list was shared before. Sharing it again replaces the
edits made on the shared page." (ADR-0008). The link dialog opens as soon as `publish`
returns. `enqueue` is still not awaited (AC-37, T18). If photos were left out, the dialog
adds "N photo(s) was/were left out: a page holds the first 10 photos taken." (spec OQ-3).
Photos have no names in the app, so the count stands in for the names.

Tests (`words_table_test.dart`, written first, 5 red before the change): switch on
with N = 2 and the note, for 4 photos where one has only a blank row and one has none;
no switch and no note without photos, or with a photo linked only to a blank row; switch
on sends the session's photos; switch off sends none; the republish warning shows only
when the session has a `publishedId`; the left-out line in the link dialog. The file
tile is still there in each sheet test. `flutter test` passes 140 tests. `flutter
analyze` still reports the 9 infos it had before, and `npm run typecheck` is clean. No
Worker code changed, so `npm test` was not run. The grep finds only
`PhotoScaler.instance`.

Left: the on-device AC-37 check (3 photos, slow network, dialog ≤ 3 s, photos appear
later) is manual and pending.
