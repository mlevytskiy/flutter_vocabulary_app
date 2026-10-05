---
id: T5
title: "Pick one photo from the gallery and run it through the shared photo chain with gallery failure texts"
layer: "app"
deps: ["T4"]
acs: ["AC-03", "AC-04", "AC-06", "AC-07", "AC-08", "AC-09", "AC-11", "AC-12", "AC-13"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "test/photo_import_flow_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T5 — Pick one photo from the gallery and run it through the shared photo chain with gallery failure texts

## Why

[spec AC-03, AC-04, AC-06–AC-09, AC-11–AC-13](../spec.md), [sad §4 choices 2–4 and tactical decisions (Gallery call, Failure messages by source, takenAt)](../sad.md), [sad §6 flow 1](../sad.md), [ADR-0002](../adr/0002-send-very-tall-images-through-the-normal-photo-path.md).

## What

- Gallery branch: `ref.read(imagePickerProvider).pickImage(source: ImageSource.gallery, requestFullMetadata: false)`.
  - It catches a picker exception, which shows the gallery text.
  - `null` shows "No photo was picked".
  - A file goes to `_processPickedPhoto(file, source: ImageSource.gallery)`.
- `_processPickedPhoto` gains `{ImageSource source = ImageSource.camera}`. It is used only to choose the text when the scaler throws: the gallery text for a gallery photo, today's "Error analyzing photo: $e" for a camera photo. `VocabPhotoException` keeps its own message for both sources. Scaling, the 20-word cap, keep-or-delete and `takenAt` stay untouched (one chain, sad §4 choice 2).
- The lost-photo recovery keeps calling `_processPickedPhoto(file)` with the default source (sad §11).

## Definition of Done

**Done when:** Gallery calls `pickImage(source: ImageSource.gallery, requestFullMetadata: false)` and feeds the file to `_processPickedPhoto(file, source: gallery)`; a picked photo reaches the results dialog and, with a kept word, becomes the session's source photo exactly like a camera photo; nothing picked shows "No photo was picked"; a throwing picker or scaler shows "The photo from the gallery could not be used. Try another one." and keeps no photo; camera texts are unchanged; all covered by widget tests in `test/photo_import_flow_test.dart`.

- [x] Widget test: a gallery pick reaches `analyzePhoto` with `limit: 20`. Done with a kept word adds the words and attaches a source photo that every added row points at, exactly as for a camera photo (AC-03, AC-04). AC-12 is then served by the unchanged publish path.
- [x] Widget test: removing every word or cancelling the results dialog leaves no source photo (the store's `delete` is called) (AC-11)
- [x] Widget test: the picker returns `null`, which shows "No photo was picked" with no camera wording and leaves the session unchanged (AC-06)
- [x] Widget test: the picker throws, then the scaler throws, and each shows the gallery text, adds no words and keeps no photo (AC-07, AC-08)
- [x] Widget test: when a camera photo's scaler throws, the app still shows "Error analyzing photo" (sad §4: camera texts unchanged)
- [x] Widget test: the fake picker records `requestFullMetadata == false` for the gallery call (AC-09)
- [x] `flutter analyze` is clean
- [x] lint clean (`flutter analyze`)

## Notes

- AC-13 (the original is unchanged) holds by construction: the chain only reads the picker's returned file. T6 checks it on the device.
- Very tall or huge images need no special case (ADR-0002). Whatever the Worker answers is shown.
- Implementation notes (T5): the Gallery branch lives in `_pickPhotoFromGallery`, a sibling of `_takePhotoFromCamera`; the gallery text is the file-level constant `_galleryPhotoUnusable`. The source-aware text sits in `_processPickedPhoto`'s generic `catch`, so any non-`VocabPhotoException` error on a gallery photo (not only a scaler failure) shows the gallery text; for the camera it is still "Error analyzing photo: $e". An extra test pins that a `VocabPhotoException` on a gallery photo keeps its own message and deletes the kept copy.
