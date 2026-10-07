---
id: T10
title: "Add WordPair.rowId, WordGroup and the StoryRun collection to the app"
layer: "domain"
deps: []
acs: ["AC-11", "AC-15", "AC-17"]
files_hint: ["lib/core/models/word_pair.dart", "lib/core/models/word_group.dart", "lib/core/models/session.dart", "lib/core/models/story_run.dart", "lib/core/services/session_store.dart", "lib/core/models/*.g.dart", "test/story_models_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T10 — Add WordPair.rowId, WordGroup and the StoryRun collection to the app

## Why

[ADR-0003](../adr/0003-keep-word-groups-in-the-session-and-story-runs-in-their-own-collection.md) (the CLAUDE.md rule 5 approval); [sad §5](../sad.md) `core/models/`.

## What

- `WordPair.rowId` (UUID from the existing `_uuidV4` helper), filled in once for older rows when `SessionStore` reads a session. Copy and equality keep it.
- `@embedded WordGroup {id, name, rowIds, storyRunId?, storyWords}`. `Session` gains `groups`, `selectedGroupId` and `groupedWordsKey`.
- `@collection StoryRun {runId (unique index), sessionId, groupId, groupName, words, startedAt (index), models, steps, outcome, collected}` + `@embedded StoryStep {role, attempt, modelId, modelName, outcome, text, picturePath, missedWords, priceUsd, priceEstimated, ms}`.
- `Isar.open([SessionSchema, StoryRunSchema], …)`.

## Definition of Done

**Done when:** The new fields and collection are generated and opened, a session saved without `rowId` gets stable row ids on its first read and keeps them, and a `StoryRun` with steps round-trips through Isar, all in `test/story_models_test.dart`.

- [ ] existing session tests still pass unchanged
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Additive Isar change only (sad §11 risk row).
- Shares `session_store.dart` with T13 (serialized).
