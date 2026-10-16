---
id: T15
title: "Add the Collections route and screen with path, Up and the icon grid, and keep the side menu always on"
layer: "ui"
deps: ["T8"]
acs: ["AC-06", "AC-07", "AC-08"]
files_hint: ["lib/router/routes.dart", "lib/features/collections/collections_screen.dart", "lib/features/collections/collections_notifier.dart", "lib/features/collections/collection_icon.dart", "lib/features/word_input/word_input_screen.dart", "test/collections_screen_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T15 — Add the Collections route and screen with path, Up and the icon grid, and keep the side menu always on

## Why

[screens SCR-03, SCR-04](../screens.md), [sad §5](../sad.md#5-building-block-view) `features/collections/`, [sad §6](../sad.md#6-runtime-view) F2, CLAUDE.md rule 1.

## What

- `CollectionsRoute` typed route; the drawer's "only with other sessions" condition removed and a **Collections** `ListTile` (folder icon) added between Main and History.
- `@riverpod` `CollectionsNotifier`: open folder id, level items from `watchLevel`, path from `watchFolders`; the current id from the notifier.
- Reuses `Drawer`, `ListTile`, `AppBar`, `CircularProgressIndicator`. New: `CollectionsPathBar`, `CollectionsGrid`, `CollectionIcon` (tap only here; drag in T17).
- The bin icon navigates nowhere yet (T19 wires it).

## Definition of Done

**Done when:** Widget tests cover SCR-03 default and SCR-04 default·top level, default·inside a folder, empty folder and loading: the side menu always holds Main, Collections, History; Collections opens the top level with path "Collections" and Up unavailable, icons in the learner's order with name, word count and a current badge, the recycle bin last with no ⋮; tapping folders grows the path, each part tappable, and Up returns one level.

- [ ] listed SCR-03/SCR-04 states built
- [ ] open-time check: a test with 300 collections and 50 folders builds the grid without per-item store reads
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Shares `word_input_screen.dart` with T11/T13/T14 → serialized by files_hint.
