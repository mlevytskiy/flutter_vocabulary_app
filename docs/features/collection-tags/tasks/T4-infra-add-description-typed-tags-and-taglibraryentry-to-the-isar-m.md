---
id: T4
title: "Add description, typed tags and TagLibraryEntry to the Isar models and regenerate the schema"
layer: "infra"
deps: ["T2"]
acs: ["AC-11", "AC-26"]
files_hint: ["lib/core/models/word_collection.dart", "lib/core/models/session_source.dart", "lib/core/models/tag_library_entry.dart", "lib/core/services/collection_store.dart"]
owner: "agent"
estimate: "S"
status: "todo"
---

# T4 — Add description, typed tags and TagLibraryEntry to the Isar models and regenerate the schema

## Why

Derives from [data-model](../data-model.md); ADR-0001, ADR-0002.

## What

Add `description`, `originTags`, `topicTags` to `WordCollection`; `originTags`, `topicTags` to `SessionSource` (+ fromJson/toJson/copy); new `TagLibraryEntry` collection with the unique (kind, key) index; register its schema in `CollectionStore.open()`; run build_runner. Legacy `tags` stays.

## Definition of Done

- [ ] JSON round-trip tests carry the new fields
- [ ] app builds and existing store tests stay green
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
