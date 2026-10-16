---
id: T2
title: "Rename Session to WordCollection across the app with every stored name pinned"
layer: "domain"
deps: ["T1"]
acs: ["AC-04"]
files_hint: ["lib/", "test/", "lib/core/models/word_collection.dart", "lib/core/services/collection_store.dart", "lib/core/services/collection_publish_service.dart", "lib/core/providers.dart", "test/fixtures/pre_rename_vocab/"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T2 — Rename Session to WordCollection across the app with every stored name pinned

## Why

[ADR-0002](../adr/0002-rename-session-to-wordcollection-with-stored-names-pinned.md), [sad §4](../sad.md#4-solution-strategy) choice 2, [data-model.md](../data-model.md) (WordCollection, StoryRun). The rename lands alone, before any behaviour change, so a data problem can only come from one place ([sad §11](../sad.md#11-risks-and-technical-debt) top risk).

## What

- Before renaming: write a small Isar database with the current build (a few sessions with words, sources, groups, dialogues, results, tags, plus story runs) into `test/fixtures/pre_rename_vocab/` and a test that opens it and counts everything.
- Rename mechanically: `Session` → `WordCollection` (`@collection @Name('Session')`), `sessionId` → `collectionId` (`@Name('sessionId')`) on `WordCollection` and `StoryRun`, `SessionStore` → `CollectionStore`, `session_store.dart` → `collection_store.dart`, `session_publish_service.dart` → `collection_publish_service.dart`, `sessionStoreProvider` → `collectionStoreProvider`, and every other Dart identifier, file and test named after session.
- Keep unchanged: Isar stored names (pinned), `SessionSource`'s stored name, shared-preferences keys (`current_session_id` …), Worker routes, JSON field names, `SourceKind` values.
- Regenerate with `dart run build_runner build --delete-conflicting-outputs`.

## Definition of Done

**Done when:** With a test Isar database written by the pre-rename build committed as a fixture, the renamed build opens it and reads every collection, word, source, group, dialogue, result, tag and story run unchanged; every existing test passes under its renamed name; `grep -rn "\bSession\b\|sessionStore\|SessionStore" lib` finds only `@Name` pins, Worker JSON fields and shared-preferences keys.

- [ ] the fixture test passes after the rename with the same counts as before
- [ ] every existing test passes (renamed test files included)
- [ ] the grep in the DoD shows only pins, Worker fields and prefs keys
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

One mechanical commit, larger than 500 LOC by nature (~150 files); accepted in sad §11 as long as nothing else is in flight. Visible text is NOT changed here — that is T25 (AC-33). The QG-2 test over a copy of the owner's real data is run in T27.
