---
id: T9
title: "Add bin, restore, erase, empty-bin and the 30-day sweep to CollectionStore"
layer: "infra"
deps: ["T4", "T8"]
acs: ["AC-20", "AC-21", "AC-22", "AC-24", "AC-25", "AC-26"]
files_hint: ["lib/core/services/collection_store.dart", "lib/core/services/source_photo_store.dart", "test/collection_bin_test.dart"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T9 — Add bin, restore, erase, empty-bin and the 30-day sweep to CollectionStore

## Why

[ADR-0005](../adr/0005-mark-a-deleted-item-in-place-and-let-a-binned-folders-contents-follow-it.md), [sad §5](../sad.md#5-building-block-view) the 30-day sweep, [sad §6](../sad.md#6-runtime-view) F4, F8, F9; QG-5.

## What

- `bin`, `restore`, `erase`, `emptyBin`, `sweepBin(DateTime now)`, `watchBin()`, plus a `binPreview(id)` that counts collections/folders inside and names the current collection staying (for SCR-07).
- A `hasSharedLink` answer for an item and its contents (for SCR-10's sentence).
- Logs: refused bin of current, sweep counts.

## Definition of Done

**Done when:** Store tests show: `bin` marks one item with `binnedAt` and `binnedFromFolderId`, refuses the current collection by re-reading the pointer inside the transaction, and for a folder holding the current collection first moves it to the folder's old place; `restore` returns to the old folder (or top level) at the old order when it fits, else the end; `erase`/`emptyBin` delete an item and everything inside in one transaction and its `source_photos/` files after the commit; `sweepBin(now)` erases only items whose 30 × 24 h are up; `watchBin()` lists bin items newest first; story runs are never deleted.

- [ ] controlled-clock sweep tests incl. a clock moved backwards
- [ ] erase removes photo files only after commit, and never `mnemonic_pictures/`
- [ ] restore into a binned or gone folder lands at top level
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Shares `collection_store.dart` with T5–T8 → serialized in that lane.
