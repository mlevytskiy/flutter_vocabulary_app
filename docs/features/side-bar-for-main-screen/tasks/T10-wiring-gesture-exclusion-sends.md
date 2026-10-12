---
id: T10
title: "Send the tab or handle rectangle to the gesture exclusion service at every change"
layer: "wiring"
deps: ["T4", "T8"]
acs: ["AC-12"]
files_hint: ["lib/features/word_input/photo_panel/photo_panel.dart", "test/photo_panel_exclusion_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T10 — Send the tab or handle rectangle to the gesture exclusion service at every change

## Why

[spec AC-12](../spec.md), [ADR-0002](../adr/0002-exclude-the-photo-tab-from-the-android-back-gesture-through-a-platform-channel.md) (send points), [sad §8 "System edge gesture"](../sad.md), sad §6 Flow 2, Flow 5, Flow 6.

## What

- After each frame where the tab's or handle's global rectangle, the stop or the visibility changed, `PhotoPanel` calls `systemGestureExclusionProvider.setRects` once (deduplicated).
- Clears on dispose and whenever no tab is shown. Logs each send with `debugPrint('VOCAB: photo panel exclusion …')`.

## Definition of Done

**Done when:** `photo_panel_exclusion_test.dart` passes against the mocked channel: closed sends the tab's on-screen rectangle after every layout and move, half-open sends the handle, full-open, the drawer open and no tab send an empty list, and the last call always matches what is on screen.

- [ ] test: mocked `vocab/system_gesture_exclusion` channel records calls through each stop, a vertical move, and a provider change to empty
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- The native effect is verified only in the device pass (T19 checklist).
