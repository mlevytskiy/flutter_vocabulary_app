---
id: T13
title: "Mount the photo panel on the main screen with Back stepping, highlight and jump"
layer: "wiring"
deps: ["T8", "T12"]
acs: ["AC-03", "AC-04", "AC-05", "AC-06", "AC-10", "AC-15"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "test/main_screen_photo_panel_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T13 — Mount the photo panel on the main screen with Back stepping, highlight and jump

## Why

[spec AC-03 to AC-06, AC-10, AC-15](../spec.md), [sad §4 "State placement" and §8 Back](../sad.md), sad §6 Flow 1, Flow 2, Flow 4.

## What

- The screen's `State` owns a `PhotoPanelController`, mounts `PhotoPanel` (passing `busy`, the controller and the jump callback), and passes the look's highlight to the selected photo's rows.
- `PopScope(canPop: controller.stop == closed)` with `onPopInvokedWithResult` calling `stepBack()`.
- On `photosWithWordsProvider` changes, `controller.retain(ids)`; with none left the panel closes and the tab goes.

## Definition of Done

**Done when:** `main_screen_photo_panel_test.dart` passes on the real `WordInputScreen`: a session with photos shows the tab; selecting a photo highlights all its rows and jumps to the first; another tap moves or clears it without scrolling; scrolling keeps half-open and the highlight; Back steps full-open → half-open → closed and leaves only when closed; a session with no photo with words has no `PopScope` interception and looks as today; deleting the selected photo's last row clears the selection.

- [ ] test: seeded session with two photos and 20 rows through the real notifier
- [ ] test: `tester.binding.handlePopRoute()` for Back
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Keeps the screen's additions small: all logic stays in `photo_panel/` (sad §11 risk on the 1693-line screen).
- Shares `word_input_screen.dart` with T12, T14 and T15 (one lane).
