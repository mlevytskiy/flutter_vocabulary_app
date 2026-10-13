---
id: T12
title: "Add FilmDialogue, Session.dialogues, WordGroup.dialogueId and StoryRun kind to the app"
layer: "domain"
deps: []
acs: ["AC-10", "AC-14"]
files_hint: ["lib/core/models/film_dialogue.dart", "lib/core/models/session.dart", "lib/core/models/word_group.dart", "lib/core/models/story_run.dart", "lib/core/models/*.g.dart", "test/dialogue_models_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T12 — Add FilmDialogue, Session.dialogues, WordGroup.dialogueId and StoryRun kind to the app

## Why

[sad §4](../sad.md) choice 3, [ADR-0003](../adr/0003-keep-film-dialogues-in-the-session-and-link-their-words-by-row-id.md), CLAUDE.md rule 5 (approved).

## What

- `@embedded FilmDialogue`: `id`, `lines`, `wordRowIds`, `scenePictureRunId?`, and the delivery fields `importId`, `importRowIds`, `pushState` (dialogue: none / pending / delivered; picture: none / pending / delivered), plus `hidden` for a pending dialogue left without words.
- `Session.dialogues` (pager order), `WordGroup.dialogueId?`, `StoryRun.kind` (`story` / `scene`) and `StoryRun.sceneText?`, all with `toJson` / `fromJson` and `copy`.
- `dart run build_runner build --delete-conflicting-outputs`. Older stored sessions and runs read with empty dialogues, a null `dialogueId` and kind `story`.

## Definition of Done

**Done when:** The new fields round-trip through Isar and JSON, and an Isar store written before this change opens with empty dialogues and story-kind runs.

- [ ] model round-trip tests
- [ ] `session_store_test.dart` and `story_models_test.dart` green
- [ ] `flutter analyze` clean, `.g.dart` committed

## Notes

- None.
