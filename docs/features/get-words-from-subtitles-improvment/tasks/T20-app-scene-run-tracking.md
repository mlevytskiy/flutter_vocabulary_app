---
id: T20
title: "Start, follow and collect scene runs in the app, and show them in Story runs"
layer: "app"
deps: ["T5", "T12"]
acs: ["AC-14", "AC-18", "AC-19"]
files_hint: ["lib/core/services/story_api_service.dart", "lib/core/story/story_run_tracker.dart", "lib/core/services/story_run_store.dart", "lib/features/words_settings/story_runs_screen.dart", "lib/features/words_settings/story_run_screen.dart", "test/story_run_tracker_test.dart", "test/story_runs_screens_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T20 — Start, follow and collect scene runs in the app, and show them in Story runs

## Why

[sad §4](../sad.md) choice 4, [ADR-0004](../adr/0004-draw-scene-pictures-as-two-step-runs-of-the-story-run-workflow.md), [sad §6](../sad.md) critical flow 2.

## What

- `startScene(dialogue)`: a new run of kind scene with the dialogue text and the prompt and picture AIs of the AI choice; started through the service; refusals map to the existing messages.
- Following, collecting, Try again and Draw again work as for stories. When a scene run finishes with a picture, it becomes the dialogue's `scenePictureRunId`, and is never redrawn on reopening (AC-14).
- The story runs list and a run's details show a scene run as two steps with the dialogue in place of a story.

## Definition of Done

**Done when:** A scene run started by the tracker is collected into Isar with its two steps and picture, sets the dialogue's scene picture, and appears in Story runs as a two-step run.

- [ ] tracker tests with a fake service: start, collect, Try again, Draw again, limit reached
- [ ] story runs screen test for a scene run
- [ ] `flutter analyze` clean

## Notes

- None.
