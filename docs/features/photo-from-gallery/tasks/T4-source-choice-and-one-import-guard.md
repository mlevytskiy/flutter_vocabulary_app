---
id: T4
title: "Open the source choice from Get words from photo, behind the one-import-at-a-time guard"
layer: "ui"
deps: ["T2", "T3"]
acs: ["AC-01", "AC-02", "AC-05", "AC-10"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "test/photo_import_flow_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T4 — Open the source choice from Get words from photo, behind the one-import-at-a-time guard

## Why

[spec AC-01, AC-02, AC-05, AC-10](../spec.md), [CONTEXT invariant "one photo import at a time"](../CONTEXT.md), [sad §4 One import at a time](../sad.md), [sad §6 flow 1](../sad.md).

## What

- Turn `_takePhotoForVocabulary` into the entry point. If `_isAnalyzingPhoto` is set, show the snackbar and return. Otherwise `await showPhotoSourceDialog(context)`: `null` returns silently, camera runs the existing camera code, and gallery is a stub until T5.
- Keep the speed-dial wiring (`onTakePhoto`) and its label. `word_input_speed_dial.dart` is not touched.
- Create `test/photo_import_flow_test.dart` with the harness: pump `WordInputScreen` in an `UncontrolledProviderScope` with the `sessionStoreProvider` override pattern from `test/word_input_definition_state_test.dart`, plus fakes for the picker, the scaler and `vocabPhotoServiceProvider`.

## Definition of Done

**Done when:** Tapping "Get words from photo" while `_isAnalyzingPhoto` is set shows "The current photo is still being analysed" and opens nothing; otherwise it opens the source choice, Camera runs today's camera path unchanged, and a closed choice does nothing; covered by widget tests in `test/photo_import_flow_test.dart` that pump `WordInputScreen` with fake `imagePickerProvider` / `photoScalerProvider` / `vocabPhotoServiceProvider`.

- [ ] Widget test: with the fake Worker call held open (an import still analysing), tapping "Get words from photo" again opens no dialog, shows the message, and the fake picker is not called (AC-10)
- [ ] Widget test: a tap opens the source choice and nothing else (AC-01)
- [ ] Widget test: closing the choice shows no snackbar, does not call the picker, and leaves the session unchanged (AC-05)
- [ ] Widget test: Camera calls `pickImage(source: ImageSource.camera)`, and a returned file reaches `analyzePhoto(limit: 20)` as before (AC-02)
- [ ] `flutter analyze` is clean
- [ ] lint clean (`flutter analyze`)

## Notes

- The guard is the existing widget-`State` flag (CLAUDE.md rule 2). Don't move it into a notifier.
- The source choice adds exactly 1 tap before the camera (spec §6). Don't add a confirmation or a remembered default (spec §3).
