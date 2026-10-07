---
id: T22
title: "Add the dialogue screen with its scene picture and open it from Start"
layer: "ui"
deps: ["T20", "T21", "T13"]
acs: ["AC-13", "AC-14", "AC-18", "AC-19"]
files_hint: ["lib/router/routes.dart", "lib/router/routes.g.dart", "lib/features/dialogue/dialogue_screen.dart", "test/dialogue_screen_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T22 — Add the dialogue screen with its scene picture and open it from Start

## Why

[sad §4](../sad.md) "Mobile UI architecture", [sad §6](../sad.md) critical flow 2, ux-flows SCR-07.

## What

- `DialogueRoute` under `learn` (`groupId`, optional `sessionId`), opened with `push` like `StoryRoute`.
- The screen shows the dialogue with every dialogue word bold, and the scene picture: shown from the phone when drawn (nothing paid), otherwise starts `startScene`, shows progress, and the failures "Could not write the picture prompt" with Try again, "The picture could not be drawn" with Draw again, and the daily-limit message (AC-18, AC-19).
- Back returns to the learn page with the group and the ticks kept. When both exercises are ticked, Back or continue leads to the story screen.

## Definition of Done

**Done when:** Start on a dialogue group without a picture starts one scene run and shows its progress and outcome; reopening shows the picture with no Worker call.

- [ ] widget tests with a fake tracker for drawn / drawing / prompt failed / picture failed / limit reached
- [ ] CLAUDE.md greps: no `Navigator.push`
- [ ] `flutter analyze` clean, `routes.g.dart` regenerated

## Notes

- Reuses the story screen's progress widget and zoomable picture.
