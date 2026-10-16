---
id: T14
title: "Show the collection's name as the main screen's title with a white edit button and the shared NameDialog"
layer: "ui"
deps: ["T3", "T8"]
acs: ["AC-01", "AC-02", "AC-03", "AC-05"]
files_hint: ["lib/features/collections/name_dialog.dart", "lib/features/word_input/word_input_screen.dart", "test/name_dialog_test.dart", "test/main_title_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T14 — Show the collection's name as the main screen's title with a white edit button and the shared NameDialog

## Why

[screens SCR-01, SCR-02](../screens.md), [sad §6](../sad.md#6-runtime-view) F1, [spec AC-01, AC-02, AC-03, AC-05](../spec.md#5-acceptance-criteria).

## What

- Reuses: `AppBar`, the white **Next** `ElevatedButton.icon` style (the edit button is the same style, pencil icon, no label), `showDialog` + `AlertDialog` + `TextField`.
- New: `NameDialog` (screens §New components) with modes rename collection / rename folder / new folder; no newline input; validation via `collection_name.dart`.
- The title watches the current collection's stored name.

## Definition of Done

**Done when:** Widget tests cover SCR-01 default, long name and default name, and SCR-02 rename, validation, success and cancel: the title shows the name with one-line ellipsis while the edit button and Next keep full size; the edit button opens NameDialog with the name selected; an invalid name keeps the dialog open with "A name must be 1 to 60 characters on one line"; Save renames through the store and the title follows.

- [ ] SCR-01 states default, long name, default name built
- [ ] SCR-02 states default·rename, default·new folder, validation, success, cancel built
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

CLAUDE.md rule 3: nothing else on the main screen changes look.
