---
id: T2
title: "Read the image picker and the photo scaler through providers in the photo chain"
layer: "wiring"
deps: []
acs: ["AC-02"]
files_hint: ["lib/core/providers.dart", "lib/core/providers.g.dart", "lib/features/word_input/word_input_screen.dart", "docs/architecture.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T2 — Read the image picker and the photo scaler through providers in the photo chain

## Why

[sad §5](../sad.md) (critic resolution: injectable picker and scaler so the §10 widget tests can use fakes), CLAUDE.md rule 2, [spec AC-02](../spec.md) (the camera behaves as today).

## What

- Add `@riverpod ImagePicker imagePicker(Ref ref) => ImagePicker();` to `lib/core/providers.dart`, next to `photoScaler`, and regenerate.
- In `word_input_screen.dart`, replace the `ImagePicker()` calls in `_takePhotoForVocabulary` and `_recoverLostPhoto` with `ref.read(imagePickerProvider)`. Replace the `PhotoScaler.instance` calls in `_processPickedPhoto` and `_keepSourcePhoto` with `ref.read(photoScalerProvider)`. Change nothing else.
- Add `imagePickerProvider` to the providers list in `docs/architecture.md` §1.

## Definition of Done

**Done when:** `imagePickerProvider` exists in `lib/core/providers.dart`; `word_input_screen.dart` no longer calls `ImagePicker()` or `PhotoScaler.instance` (it reads `imagePickerProvider` and `photoScalerProvider`); `build_runner`, `flutter analyze` and the existing `flutter test` suite pass with camera behaviour unchanged.

- [ ] `dart run build_runner build --delete-conflicting-outputs` regenerates `providers.g.dart`
- [ ] `grep -n "ImagePicker()\|PhotoScaler.instance" lib/features/word_input/word_input_screen.dart` finds nothing
- [ ] `flutter test` passes (no behaviour change)
- [ ] `flutter analyze` is clean
- [ ] lint clean (`flutter analyze`)

## Notes

- This task is a pure refactor and lands before any behaviour change, so T4 and T5 can be test-first against fakes.
- It shares `word_input_screen.dart` with T4 and T5, so `implement` serializes them.
