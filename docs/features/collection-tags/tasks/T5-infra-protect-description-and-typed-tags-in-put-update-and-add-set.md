---
id: T5
title: "Protect description and typed tags in put/update and add setDetails, create(details), addCollectionTags and the library writes"
layer: "infra"
deps: ["T4"]
acs: ["AC-06", "AC-09", "AC-12", "AC-15", "AC-18", "AC-28", "AC-29", "AC-30", "AC-33"]
files_hint: ["lib/core/services/collection_store.dart", "test/collection_tags_store_test.dart"]
owner: "agent"
estimate: "L"
status: "todo"
---

# T5 — Protect description and typed tags in put/update and add setDetails, create(details), addCollectionTags and the library writes

## Why

Derives from [ADR-0004](../adr/0004-protect-description-and-typed-tags-in-put-and-write-them-only-through-store-transactions.md), [ADR-0009](../adr/0009-write-the-tag-library-inside-collectionstore-transactions-and-expose-it-and-the-summaries-as-core-providers.md), sad §6 Flows 1, 2, 3, 5, 7.

## What

`put()`/`update()` copy description + typed tags from the stored record. `setDetails(id, {name, description, origin, topic})` → stored record (moves updatedAt + lastLocalModifiedAt only on change; sets keep for a non-empty description/any tag; touches library for newly added tags). `create(folderId, details)`. `saveSourceNote(id, sourceId, ...)` / `addCollectionTags(id, kind, tags) → notAdded` in one transaction (newly added = not in the stored source, ignoring case; cap 10; touches lastUsedAt in all branches; clears forgotten). `forgetTag(kind, key)`. `watchLibrary()`.

## Definition of Done

- [ ] stale `put()` after setDetails/addCollectionTags keeps description, typed tags, updatedAt, lastLocalModifiedAt for every writer path (autosave, markShared, updateDialogues, markDialoguesPublished, story run, learn result, late lookup) — QG-1
- [ ] copy-up cap returns notAdded kinds; re-saving an unchanged source copies nothing; a re-add after removal copies again
- [ ] library: first spelling wins, Forget hides, explicit add un-forgets
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
