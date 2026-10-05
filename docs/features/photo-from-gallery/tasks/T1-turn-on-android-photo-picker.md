---
id: T1
title: "Turn on the Android Photo Picker for gallery picks"
layer: "wiring"
deps: []
acs: ["AC-09"]
files_hint: ["pubspec.yaml", "pubspec.lock", "lib/main.dart", "docs/architecture.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Turn on the Android Photo Picker for gallery picks

## Why

[ADR-0001](../adr/0001-turn-on-the-android-photo-picker-for-gallery-picks.md), [sad §2 Conventions](../sad.md) (owner-approved CLAUDE.md rule 5 override), [spec AC-09](../spec.md).

## What

- Add `image_picker_android: ^0.8.13` and `image_picker_platform_interface: ^2.11.1` under `dependencies` in `pubspec.yaml`. Both are already resolved in `pubspec.lock` as transitive dependencies; `flutter pub get` only flips them to `direct main`.
- In `lib/main.dart`, next to `PhotoScaler.instance.start()`, add one line: if `ImagePickerPlatform.instance` is an `ImagePickerAndroid`, set `useAndroidPhotoPicker = true`.
- In `docs/architecture.md` rule 6, add the two packages to the list of approved additions, citing ADR-0001.

## Definition of Done

**Done when:** `image_picker_android` and `image_picker_platform_interface` are direct dependencies in caret ranges matching the lockfile, `main.dart` sets `useAndroidPhotoPicker = true` on Android only, the Android manifest gains no permission, and `flutter analyze` (including `depend_on_referenced_packages`) is clean.

- [ ] `flutter pub get` succeeds and `pubspec.lock` shows both packages as `direct main` at the versions already resolved
- [ ] `flutter analyze` is clean, with no `depend_on_referenced_packages` warning
- [ ] `git diff android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist` is empty
- [ ] lint clean (`flutter analyze`)

## Notes

- The line must be harmless on iOS: there `ImagePickerPlatform.instance` is not an `ImagePickerAndroid`, so the type check skips it.
- The fallback on phones without the Photo Picker (no backport manifest entry) is accepted in sad §11. Don't add the entry here.
