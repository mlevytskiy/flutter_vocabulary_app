---
id: T15
title: "Add the story run tracker that starts, follows and collects runs"
layer: "app"
deps: ["T12", "T13"]
acs: ["AC-06", "AC-07", "AC-08", "AC-08b", "AC-09", "AC-10", "AC-16", "AC-19"]
files_hint: ["lib/core/story/story_run_tracker.dart", "lib/core/story/word_groups_notifier.dart", "test/story_run_tracker_test.dart"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T15 — Add the story run tracker that starts, follows and collects runs

## Why

[ADR-0002](../adr/0002-run-each-story-run-as-a-cloudflare-workflow.md); [sad §6](../sad.md) S-02, S-04, S-05, S-08.

## What

- `keepAlive` notifier. `startFor(group, {replacing})` saves a `StoryRun`, calls `startRun` and records refusals (day limit, not offered).
- Follows uncollected runs with one `status` call every 5 s while a story-related screen holds a `follow()` handle, plus once on app start. Backs off on `rateLimited`.
- Records new steps. On the picture step: download, compress, store, mark collected, and set the group's `storyRunId` and `storyWords` — for a new story only when it finishes with a picture (AC-16).
- `redoPrompt(run)` and `drawAgain(run)` with the picture maker chosen now.
- Wires the T14 start hook.

## Definition of Done

**Done when:** With fake service and stores, `test/story_run_tracker_test.dart` shows a run going started → each step → collected with the group's story set; a restart mid-run collects without a second start; a failed new run leaves the old story; prompt redo and Draw again call redo; refusals are recorded; and polling stops when no screen follows.

- [ ] no polling while no follower and nothing uncollected
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- L: about one day. Shares `word_groups_notifier.dart` with T14 (serialized after it).
