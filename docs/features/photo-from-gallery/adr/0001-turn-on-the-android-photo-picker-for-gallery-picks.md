---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-10-06"
feature_size: "XS"
ticket: "docs/features/photo-from-gallery/spec.md"
---

# 0001 — Turn on the Android Photo Picker for gallery picks

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The Gallery choice opens the phone's own picker for one photo (spec §1). On iOS 14+, `image_picker_ios` already uses PHPicker, a photo grid that needs no permission. On Android, `image_picker_android` 0.8.13+17 (what `image_picker` ^1.1.2 resolves to) has `useAndroidPhotoPicker = false` by default. A gallery pick then sends `ACTION_GET_CONTENT` for `image/*`, and depending on the phone this shows a photo grid or a file browser with Recent and Downloads. The flag can only be set on the `ImagePickerAndroid` instance, reached through `ImagePickerPlatform.instance` from `image_picker_platform_interface`, which `image_picker` 1.2.2 does not re-export. Importing either from a package that is only a transitive dependency breaks the `depend_on_referenced_packages` lint, and CLAUDE.md rule 5 says new packages need the owner's approval first.

## Decision drivers

- Spec §1 / US-02: "the system photo picker for a single photo". The learner looks for a page among their photos, not their files.
- AC-09 and spec §6 "0 new permission prompts": only the picked photo reaches the app, and the app asks for no library access.
- CLAUDE.md rule 5: no new packages without asking. Rule 3: keep the code change small.

## Considered options

1. **Turn on the Photo Picker.** Add `image_picker_android` and `image_picker_platform_interface` as direct dependencies and set `useAndroidPhotoPicker = true` once at startup on Android.
2. **Keep the `image_picker` default.** Gallery picks on Android use `ACTION_GET_CONTENT`, with no dependency change.

## Decision outcome

**Chosen:** Option 1. The owner approved both dependencies in the design walk (the second one after the critic pass). It gives the learner the same photo grid on every Android phone that has the Photo Picker, which matches the spec's "system photo picker", and like option 2 it needs no permission. The added dependencies ship no new code: they are packages `image_picker` already pulls in, now named in `pubspec.yaml`.

## Consequences

**Positive**
- Every Android phone with the system Photo Picker (built in from Android 13, delivered to Android 11–12 through Google Play system updates) shows a photo grid, like iOS.
- No storage or media permission and no manifest change. AC-09 holds on both platforms.

**Negative**
- Two more lines in `pubspec.yaml` whose versions must stay compatible with `image_picker`'s, declared as caret ranges (`^0.8.13`, `^2.11.1`).
- One platform-specific line in `main.dart`.

**Neutral**
- Older phones get the Photo Picker only through the Google Play services backport. Its manifest entry is not added in v1, so a phone without the picker falls back to the system document picker (still one photo, no permission), much like option 2 on that phone (sad §11).
- Reverting is one line plus the two dependencies.

## Links

- Spec: [[../spec.md]] §1, US-02, AC-09
- SAD: [[../sad.md]] §4 (choice 3), §2, §11
- Related ADR: [[0002-send-very-tall-images-through-the-normal-photo-path]]
