---
id: T5
title: "Add the filing fields and CollectionFolder to Isar, and make put() keep filing and never insert"
layer: "infra"
deps: ["T2", "T3"]
acs: ["AC-19", "AC-27"]
files_hint: ["lib/core/models/word_collection.dart", "lib/core/models/word_collection.g.dart", "lib/core/models/collection_folder.dart", "lib/core/models/collection_folder.g.dart", "lib/core/services/collection_store.dart", "lib/features/word_input/word_input_notifier.dart", "test/collection_store_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T5 — Add the filing fields and CollectionFolder to Isar, and make put() keep filing and never insert

## Why

[ADR-0003](../adr/0003-keep-filing-on-the-collection-row-written-only-by-store-transactions.md), [ADR-0004](../adr/0004-store-folders-as-their-own-isar-collection-linked-by-parent-id.md), [data-model.md](../data-model.md) Entities, `put()` contract and Indexes.

## What

- New properties and indexes exactly as data-model.md (`folderId`, `binnedAt` value indexes; `CollectionFolder.folderId` unique hash, `binnedAt` index).
- `CollectionStore.create({folderId, keep})`: inserts with `name = defaultCollectionName(now)` from T3, `order` at the end of its level.
- `put()` per the contract; every caller that relied on put() inserting (`_startNewSession` in `word_input_notifier.dart`) switches to `create()` in this same task, so the tree stays green (contract-task rule).

## Definition of Done

**Done when:** `WordCollection` has `name`, `folderId`, `order`, `binnedAt`, `binnedFromFolderId`, `keep` with the indexes in data-model.md, `CollectionFolder` is registered in the store; store tests show `put()` copies the six fields from the stored record, raises `keep` to true only when the copy has a word, never lowers it, and writes nothing when no record with that id exists, while `create()` inserts a kept or unkept new collection with its default name.

- [ ] store tests over a temp Isar dir for each `put()` rule
- [ ] the existing word input tests still pass
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Compile-coupled with the notifier's new-collection path: both change in this task. Depends on T3 only through `defaultCollectionName`; after T2 because it edits the renamed files.

Found while implementing (2026-10-16): Isar does not apply a Dart field default to a property an old record lacks, so a pre-feature record reads `order` as Isar's null long (`-9223372036854775808`), not `0` (`keep` reads `false`, the nullable fields `null`, as data-model.md says). Pinned in `test/pre_rename_fixture_test.dart`. Harmless because T6's backfill numbers every record with `name == null`. Tests that seed stored collections use `seedCollection(store, c)` from `test/seed_collections.dart`, since `put()` no longer inserts.
