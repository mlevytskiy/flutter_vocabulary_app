---
id: T12
title: "Add open(id) and newCollection(folderId) to the main screen's notifier with the AC-19 leave rule"
layer: "app"
deps: ["T8", "T11"]
acs: ["AC-09", "AC-10", "AC-12", "AC-18", "AC-19"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "test/open_collection_test.dart", "test/switch_session_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T12 — Add open(id) and newCollection(folderId) to the main screen's notifier with the AC-19 leave rule

## Why

[sad §5](../sad.md#5-building-block-view) (Collections calls the notifier), [sad §6](../sad.md#6-runtime-view) flow 2, F3, F7.

## What

- Reuse `switchTo`'s flush-and-leave code for `open`; the leave check uses `filing.dart`'s `isEmptyAndUntouched` instead of `isEmpty`.
- `newCollection` calls `CollectionStore.create(folderId:, keep: true)`.

## Definition of Done

**Done when:** Notifier tests show: `open` of another collection flushes the autosave, erases the left collection at once only when it is empty and untouched (not kept, no words, sources, notes or tags), sets the pointer and shows the opened collection with no question; `open` of the current one changes nothing; `newCollection(folderId)` makes a kept, empty, date-named collection at the end of that folder and makes it current; History's switch still works.

- [ ] leave-rule cases: never-touched empty erased; renamed / moved / New-collection empty kept; with words kept
- [ ] an erased-on-leave collection never shows in History or the bin
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
