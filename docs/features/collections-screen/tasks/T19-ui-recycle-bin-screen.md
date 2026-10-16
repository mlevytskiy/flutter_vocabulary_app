---
id: T19
title: "Add the recycle bin screen with days left, Restore, Delete forever and Empty recycle bin"
layer: "ui"
deps: ["T9", "T15"]
acs: ["AC-23", "AC-24", "AC-25"]
files_hint: ["lib/router/routes.dart", "lib/features/collections/recycle_bin_screen.dart", "lib/features/collections/collections_screen.dart", "test/recycle_bin_screen_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T19 — Add the recycle bin screen with days left, Restore, Delete forever and Empty recycle bin

## Why

[screens SCR-08, SCR-09, SCR-10](../screens.md), [sad §6](../sad.md#6-runtime-view) F9.

## What

- `RecycleBinRoute` typed route; reuses `ListView`, `ListTile`, `PopupMenuButton`, `AlertDialog`, `SnackBar`.
- Days left from `filing.dart`.

## Definition of Done

**Done when:** Widget tests cover SCR-08 default, empty, loading, restored and erased, SCR-09 and SCR-10 (one item, with a shared link, empty the bin, cancel): the bin opens only from the top-level bin icon, lists items newest deleted first with name, "N words" for collections and "N days left"; a collection here never opens; Restore shows "Restored to <folder or Collections>"; Delete forever and Empty confirm with "cannot be undone" and the shared-page sentence when any item was published.

- [ ] all listed SCR-08/09/10 states built
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
