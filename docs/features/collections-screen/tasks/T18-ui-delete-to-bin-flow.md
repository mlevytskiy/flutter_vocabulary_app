---
id: T18
title: "Delete from the menu or the bin drop zone with the confirmation, the current-collection refusal and the stayed message"
layer: "ui"
deps: ["T9", "T17"]
acs: ["AC-14", "AC-20", "AC-21", "AC-22"]
files_hint: ["lib/features/collections/collections_screen.dart", "lib/features/collections/collection_drag.dart", "lib/features/collections/bin_drop_zone.dart", "test/collections_delete_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T18 — Delete from the menu or the bin drop zone with the confirmation, the current-collection refusal and the stayed message

## Why

[screens SCR-04, SCR-07](../screens.md), [sad §6](../sad.md#6-runtime-view) F8.

## What

- Reuses `AlertDialog`, `SnackBar`. New: `BinDropZone`, shown only while dragging inside a folder.
- Counts and the staying name come from `binPreview` (T9).

## Definition of Done

**Done when:** Widget tests cover SCR-07 (collection, folder, folder with current, cancel) and SCR-04 refused·current and current stayed: Delete or a drop on `BinDropZone` (inside folders) or the bin icon (top level) shows the confirmation with the name and word count or the folder's counts; confirming bins through the store; the current collection is refused with "The current collection cannot be deleted. Open another collection first."; a folder holding it leaves the current collection in the folder's place with "<name> stayed here because it is the current collection."

- [ ] all listed SCR-07 states built
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
