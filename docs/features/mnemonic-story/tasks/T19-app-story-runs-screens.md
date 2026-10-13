---
id: T19
title: "Add the story runs list and a run's details screen"
layer: "ui"
deps: ["T18"]
acs: ["AC-14", "AC-15"]
files_hint: ["lib/router/routes.dart", "lib/router/routes.g.dart", "lib/features/words_settings/story_runs_screen.dart", "lib/features/words_settings/story_run_screen.dart", "test/story_runs_screens_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T19 — Add the story runs list and a run's details screen

## Why

[ux-flows](../ux-flows.md) SCR-06, SCR-07 and Flow US-04; [sad §6](../sad.md) S-07.

## What

- `StoryRunsRoute` and `StoryRunRoute(runId)` under `WordsSettingsRoute`.
- The list, newest first: group name, date, the three AIs, total price, total time (the sum of step times), and finished or where it stopped. "No story runs yet" when empty.
- Details: each step's AI and result (story, prompt, picture), price ("≈" when estimated) and time, failed attempts included.

## Definition of Done

**Done when:** Widget tests in `test/story_runs_screens_test.dart` show the empty state, the newest-first list with totals as sums of step times and prices, stopped and replaced runs still listed, and a run's details with failed attempts and estimated prices marked "≈".

- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Reads only `StoryRunStore`; no network.
