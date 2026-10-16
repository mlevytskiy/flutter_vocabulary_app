---
id: T7
title: "Add CollectionStore.update(id, change) and move every background writer onto it"
layer: "infra"
deps: ["T5"]
acs: ["AC-11", "AC-27"]
files_hint: ["lib/core/services/collection_store.dart", "lib/core/story/story_run_tracker.dart", "lib/core/story/word_groups_notifier.dart", "lib/core/dialogues/dialogue_push.dart", "lib/core/services/exam_result_sink.dart", "test/collection_store_update_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T7 — Add CollectionStore.update(id, change) and move every background writer onto it

## Why

[ADR-0006](../adr/0006-deliver-late-results-into-their-own-collection-through-an-atomic-store-update.md), [sad §2](../sad.md#2-constraints) (the four whole-copy writers), [sad §6](../sad.md#6-runtime-view) F10.

## What

- `Future<bool> update(String collectionId, void Function(WordCollection) change)`; the change may not touch filing fields (the store restores them after the callback).
- Replace `put(session)` at `story_run_tracker.dart:465,489`, `word_groups_notifier.dart:213`, `dialogue_push.dart:331` with `update` calls that change only their own fields; fold `appendResult` into `update`.
- Log a dropped write: `VOCAB: update for <id> dropped, collection erased`.

## Definition of Done

**Done when:** `update(id, change)` reads, changes and writes one record in one transaction and does nothing when the record is gone; `story_run_tracker`, `word_groups_notifier`, `dialogue_push` and `appendResult` use it instead of a whole-copy `put()`; tests show each writer leaves a concurrent rename, move and bin mark intact and writes nothing for an erased collection.

- [ ] one test per writer: filing change between its read and its write survives
- [ ] erased collection: writer's result dropped, no record re-created
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

The main screen's autosave keeps `put()` (now filing-safe from T5). The late results of translation, photo reading and imports are T13.
