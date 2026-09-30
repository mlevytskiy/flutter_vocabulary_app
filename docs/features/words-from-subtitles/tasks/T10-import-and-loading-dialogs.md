---
id: T10
title: "Add file_selector and build the import dialog and the loading dialog"
layer: "ui"
deps: ["T6"]
acs: ["AC-01", "AC-09", "AC-11"]
files_hint: ["pubspec.yaml", "lib/features/word_input/widgets/subtitle_import_dialog.dart", "lib/features/word_input/widgets/import_loading_dialog.dart", "test/subtitle_import_dialog_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T10 — Add file_selector and build the import dialog and the loading dialog

## Why

[ux-flows.md](../ux-flows.md) SCR-02 to SCR-04; [sad §4](../sad.md) File package; [sad §6 F1](../sad.md); [sad §8](../sad.md) Late results (non-dismissible).

## What

- Add `file_selector` to `pubspec.yaml`: the one package the owner approved (spec §1); no other package changes.
- `subtitle_import_dialog.dart`: opens the chooser with no type filter, then checks the extension (`.srt` / `.vtt` is checked again at Start, F3) and the size.
- `import_loading_dialog.dart`: `barrierDismissible: false` and `PopScope(canPop: false)`.

## Definition of Done

**Done when:** Widget tests (file picking behind an injectable callback) show the import dialog (SCR-02) opening with the stored purpose, level and maximum; Start disabled until a file is chosen and the maximum is 1–100; a file over 1,048,576 bytes refused with "too large, the largest accepted is 1 MB" and Start disabled; a cancelled pick leaving the dialog unchanged; Start returning the file bytes, extension and chosen values; the loading dialog (SCR-04) not dismissible by the barrier or back.

- [ ] `flutter pub get`
- [ ] `flutter test test/subtitle_import_dialog_test.dart`
- [ ] `flutter analyze`
- [ ] a manual pick on an Android device opens the system chooser and returns a file
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- No platform permission is needed for `file_selector` on Android or iOS. Confirm on the device, and if one turns out to be needed, stop and note it in the task (CLAUDE.md rule 6).
