---
id: T4
title: "Add the gesture exclusion service and its Android channel handler"
layer: "infra"
deps: []
acs: ["AC-12"]
files_hint: ["lib/core/services/system_gesture_exclusion.dart", "lib/core/providers.dart", "android/app/src/main/kotlin/com/unique/androidvocabularyapp2/MainActivity.kt", "test/system_gesture_exclusion_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T4 — Add the gesture exclusion service and its Android channel handler

## Why

[spec AC-12](../spec.md), [ADR-0002](../adr/0002-exclude-the-photo-tab-from-the-android-back-gesture-through-a-platform-channel.md), [sad §4 choice 3 and §8 "System edge gesture"](../sad.md).

## What

- `SystemGestureExclusion.setRects(List<Rect>)` sends the rectangles over `MethodChannel('vocab/system_gesture_exclusion')`; never throws; does nothing when not on Android. `systemGestureExclusionProvider` in `lib/core/providers.dart`.
- `MainActivity.kt`: `configureFlutterEngine` registers the channel; on Android 10+ (API 29) it sets `window.decorView.systemGestureExclusionRects`; below that it answers success and does nothing.

## Definition of Done

**Done when:** `system_gesture_exclusion_test.dart` passes against a mocked `vocab/system_gesture_exclusion` channel (rects sent in physical pixels, empty list clears, platform errors swallowed, no call off Android), and `MainActivity.kt` builds in `flutter build apk --debug`.

- [ ] test: mocked channel through `TestDefaultBinaryMessengerBinding`: one call per `setRects`, clear sends an empty list, a `PlatformException` is swallowed
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- The first native code and the first `MethodChannel` in the app (sad §2).
- The 200 dp per-edge limit is enforced by the look interface (T6), not here.
