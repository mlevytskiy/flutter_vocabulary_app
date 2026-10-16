---
id: T17
title: "Drag icons into folders, up a level, onto the path and into a new order, with hover-to-open"
layer: "ui"
deps: ["T16"]
acs: ["AC-14", "AC-15", "AC-16"]
files_hint: ["lib/features/collections/collection_drag.dart", "lib/features/collections/collection_icon.dart", "lib/features/collections/collections_screen.dart", "test/collections_drag_test.dart"]
owner: "Maksym"
estimate: "L"
status: "done"
---

# T17 — Drag icons into folders, up a level, onto the path and into a new order, with hover-to-open

## Why

[screens SCR-04](../screens.md) dragging states, [sad §6](../sad.md#6-runtime-view) F6, QG-6 in [sad §10](../sad.md#10-quality-requirements), [sad §2](../sad.md#2-constraints) (no drag package).

## What

- Flutter's own `LongPressDraggable` + `DragTarget`; drop-target rules and the 1 s hover timer in widget `State` (`collection_drag.dart`).
- Gaps between icons as reorder targets; path parts and Up as move targets.

## Definition of Done

**Done when:** Widget tests cover SCR-04 dragging, hover-open, refused·into itself and no-op drop: a long press that moves starts a drag; drops on a folder icon, Up, a path part, a gap or another collection's icon move or reorder through the store; a folder dropped into itself or a descendant springs back with "A folder cannot go inside itself"; empty-spot, own-level and top-level-Up drops do nothing; holding over a folder for about 1 s opens it mid-drag; 50 scripted drags of every kind change the current-collection pointer 0 times (QG-6).

- [ ] QG-6: 50 scripted drags, 0 pointer changes
- [ ] drag does not fight the grid's scroll or the drawer edge swipe in a widget test
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

The bin drop zone is T18.
