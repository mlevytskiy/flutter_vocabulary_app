---
id: T10
title: "Add the Collection details sheet with Discard changes and wire New collection and the main screen's edit button to it"
layer: "ui"
deps: ["T7", "T8", "T9"]
acs: ["AC-01", "AC-02", "AC-03", "AC-05", "AC-27", "AC-36"]
files_hint: ["lib/features/collections/collection_details_sheet.dart", "lib/features/collections/collections_screen.dart", "lib/features/word_input/word_input_screen.dart", "test/collection_details_sheet_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T10 — Add the Collection details sheet with Discard changes and wire New collection and the main screen's edit button to it

## Why

Derives from screens SCR-02, SCR-03; ux-flows US-01, US-02.

## What

`showCollectionDetailsSheet(context, {initial, mode: create|edit})` returning the details; Create → store create(details) + open (as `_newCollection` does today); edit button on SCR-01 opens it in edit mode → notifier.saveDetails. Folders keep NameDialog.

## Definition of Done

- [ ] widget tests: Create with name only; invalid name/description disables the button with a message; dismiss after change asks Discard changes?; edit Save updates title
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
