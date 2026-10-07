---
id: T17
title: "Add the story screen and open it from Start for Mnemonic story"
layer: "ui"
deps: ["T15", "T11"]
acs: ["AC-06", "AC-07", "AC-08", "AC-08b", "AC-09", "AC-16", "AC-17", "AC-19"]
files_hint: ["lib/router/routes.dart", "lib/router/routes.g.dart", "lib/features/mnemonic_story/story_screen.dart", "lib/features/mnemonic_story/widgets/new_story_dialog.dart", "lib/features/learn/learn_screen.dart", "test/story_screen_test.dart"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T17 — Add the story screen and open it from Start for Mnemonic story

## Why

[ux-flows](../ux-flows.md) SCR-04 and Flows US-02, US-05; [sad §4](../sad.md) "Mobile UI architecture"; [sad §6](../sad.md) S-04, S-05, S-08.

## What

- `StoryRoute` under `learn` (`sessionId?`, `groupId`). Start with `mnemonic-story` ticked pushes it instead of `ComingSoonRoute`; other exercises keep coming soon.
- Story screen: the running step label; picture in an `InteractiveViewer` (max scale ≥ 4, as `photo_viewer.dart`) over the story text; the failure messages with Try again / Draw again; the "Words changed" mark; "Make a new story" → confirmation dialog → new run, with the old story kept and "The new story could not be made" on failure; the daily-limit text.
- Holds a tracker `follow()` handle while visible.

## Definition of Done

**Done when:** Widget tests in `test/story_screen_test.dart` cover a saved story (no service call), each running label, each failure message with its button, Draw again, Words changed, the confirm/cancel dialog, a failed new story keeping the old one, and the limit text.

- [ ] `InteractiveViewer` allows at least 4× zoom
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Shares `routes.dart` with T18 and `learn_screen.dart` with T16 (serialized).
