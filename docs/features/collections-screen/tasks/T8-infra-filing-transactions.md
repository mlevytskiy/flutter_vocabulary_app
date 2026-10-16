---
id: T8
title: "Add rename, new folder, move and reorder transactions and the level, path and History streams"
layer: "infra"
deps: ["T4", "T5"]
acs: ["AC-01", "AC-13", "AC-14", "AC-15", "AC-17", "AC-28"]
files_hint: ["lib/core/services/collection_store.dart", "test/collection_filing_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T8 — Add rename, new folder, move and reorder transactions and the level, path and History streams

## Why

[ADR-0003](../adr/0003-keep-filing-on-the-collection-row-written-only-by-store-transactions.md), [sad §6](../sad.md#6-runtime-view) F1, F2, F5, F6, F11; [data-model.md](../data-model.md) access patterns.

## What

- Each action is one `writeTxn`, not debounced (QG-4), and returns a result enum (`done`, `invalidName`, `intoItself`, `notFound`) instead of throwing.
- Rules come from `filing.dart` (T4) and `collection_name.dart` (T3).
- `watchHistory()` replaces `watchNonEmpty()`; History and the tag suggestions move to it.

## Definition of Done

**Done when:** Store tests over a temp Isar show: `rename` writes only `name` (and raises `keep` for a collection) and refuses an invalid name; `createFolder` appends at the end of its level; `move` changes `folderId`/`parentId`, renumbers both levels and refuses a folder into itself or a descendant; `reorder` renumbers one level with folders and collections sharing the order; `watchLevel(folderId)` emits that level's unbinned items by order, `watchFolders()` gives the tree for the path, and `watchHistory()` emits non-empty collections outside the bin (directly or through an ancestor), newest first.

- [ ] one test per action and per refusal
- [ ] streams re-emit after each transaction
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
