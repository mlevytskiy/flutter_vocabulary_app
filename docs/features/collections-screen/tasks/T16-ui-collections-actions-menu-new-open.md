---
id: T16
title: "Open a collection with a tap, add New folder and New collection, and the item menu with Rename"
layer: "ui"
deps: ["T12", "T14", "T15"]
acs: ["AC-09", "AC-10", "AC-13", "AC-17", "AC-18"]
files_hint: ["lib/features/collections/collections_screen.dart", "lib/features/collections/collections_notifier.dart", "lib/features/collections/collection_icon.dart", "test/collections_actions_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T16 — Open a collection with a tap, add New folder and New collection, and the item menu with Rename

## Why

[screens SCR-04, SCR-05, SCR-02](../screens.md), [sad §6](../sad.md#6-runtime-view) F1, F3, F5, F7.

## What

- Reuses `PopupMenuButton` for SCR-05 and T14's `NameDialog`.
- Delete in the menu calls a placeholder that T18 fills.

## Definition of Done

**Done when:** Widget tests show: a tap on a collection opens the main screen on it with no question (and changes nothing when it is already current); New folder asks for a name and appends the folder; New collection makes a current, empty, date-named collection at the end of the open folder and opens the main screen; the ⋮ button and a long press released without moving open SCR-05 with Rename and Delete, and Rename updates the icon and, for the current collection, the title.

- [ ] SCR-05 default and current-collection states built
- [ ] no `Navigator.push`: navigation through typed routes
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
