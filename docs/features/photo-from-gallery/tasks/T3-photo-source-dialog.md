---
id: T3
title: "Add the Camera/Gallery source choice dialog"
layer: "ui"
deps: []
acs: ["AC-01", "AC-05"]
files_hint: ["lib/features/word_input/widgets/photo_source_dialog.dart", "test/photo_source_dialog_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T3 — Add the Camera/Gallery source choice dialog

## Why

[spec AC-01, AC-05](../spec.md), [sad §4 tactical decisions, Source choice](../sad.md).

## What

- A top-level `Future<ImageSource?> showPhotoSourceDialog(BuildContext context)` built on `showDialog`: a small dialog with two Material list entries, Camera (`Icons.camera_alt`) and Gallery (`Icons.photo_library`). Each entry pops its `ImageSource`, and the barrier stays dismissible.
- Reuse what is already there: the Material `SimpleDialog` / `SimpleDialogOption` (or `AlertDialog` + `ListTile`) the app's other dialogs use, with no new widget primitives, colours or styles. It is a dialog, not a route (CLAUDE.md rule 1).

## Definition of Done

**Done when:** `showPhotoSourceDialog(context)` in `lib/features/word_input/widgets/photo_source_dialog.dart` shows exactly two choices, Camera and Gallery, returns `ImageSource.camera` / `ImageSource.gallery` for them and `null` when the dialog is closed by tapping outside or going back; covered by `test/photo_source_dialog_test.dart`.

- [ ] A widget test confirms the dialog shows exactly the two labels Camera and Gallery
- [ ] Widget tests: tapping Camera returns `ImageSource.camera`, and tapping Gallery returns `ImageSource.gallery`
- [ ] Widget tests: tapping the barrier returns `null`, and a back pop returns `null` (AC-05)
- [ ] `flutter analyze` is clean
- [ ] lint clean (`flutter analyze`)

## Notes

- No `screens.md` exists for this XS feature, so this dialog is the whole screen contract (sad §4).
- It doesn't depend on the other tasks, so it can start in parallel with T1 and T2.
