---
id: T13
title: "Add the story run store and the picture store to the app"
layer: "infra"
deps: ["T10"]
acs: ["AC-07", "AC-14", "AC-15"]
files_hint: ["lib/core/services/story_run_store.dart", "lib/core/services/story_picture_store.dart", "lib/core/services/session_store.dart", "lib/core/providers.dart", "test/story_stores_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T13 — Add the story run store and the picture store to the app

## Why

[sad §5](../sad.md) stores; [ADR-0003](../adr/0003-keep-word-groups-in-the-session-and-story-runs-in-their-own-collection.md); [spec §6](../spec.md) Storage.

## What

- `StoryRunStore`: put, by id, newest first, uncollected, `watch(runId)`. It never removes anything. It does not throw, like `SessionStore`.
- `StoryPictureStore`: write compressed (`flutter_image_compress`) to `mnemonic_pictures/<runId>-<attempt>.jpg` at ≤ 3 MB, read and exists. Never throws, like `source_photo_store.dart`.

## Definition of Done

**Done when:** Runs round-trip and list newest first, uncollected runs are found, and an oversized picture is written at ≤ 3 MB, in `test/story_stores_test.dart`.

- [ ] providers registered in `lib/core/providers.dart`
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Shares `providers.dart` with T12 and `session_store.dart` with T10.
