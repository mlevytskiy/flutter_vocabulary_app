---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0009 — Write the tag library inside CollectionStore transactions and expose it and the summaries as core providers

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

ADR-0002 promises that a collection change and its library touch happen in one transaction. A separate `TagLibraryStore` service would need its own `writeTxn`, and Isar does not nest write transactions. Screens need the library and the summaries through providers (CLAUDE.md rule 2). `_watchFiling` watches only collections and folders (`collection_store.dart:641-643`), so it would not see library changes.

## Decision drivers

- Atomic collection + library writes (AC-09, AC-32, QG-1).
- Rule 2: services and data come from `core/providers.dart`.
- Suggestions must update after Forget and after adds (AC-12, AC-30).

## Considered options

1. **Library writes are `CollectionStore` methods**: `touchTags` (private, called inside `setDetails`, `addCollectionTags`, `create(details)` and the migration) and `forgetTag`. `watchLibrary()` watches `TagLibraryEntry`. `core/providers.dart` exposes `collectionSummaries` and `tagLibrary` stream providers, and `features/tags/tag_suggestions.dart` derives `tagSuggestions(kind)` from both.
2. **A separate `TagLibraryStore`** sharing the Isar instance, whose methods take an open transaction from the caller.

## Decision outcome

**Chosen:** option 1. One owner of every write transaction keeps atomicity simple, and the store already owns the Isar instance. Option 2 spreads the transaction across two services and needs a "must be called inside a txn" convention that nothing enforces.

## Consequences

**Positive**
- Atomic writes, and one place to test them.

**Negative**
- `collection_store.dart` grows further (already the largest service).

**Neutral**
- The library code can move to its own file later as a `part` or extension of the store.

## Links

- Spec: [[../spec.md]] AC-09, AC-12, AC-30, AC-32
- SAD: [[../sad.md]] §5, §8
- Related ADR: [[0002-keep-the-tag-library-in-its-own-isar-collection-and-count-uses-live]], [[0004-protect-description-and-typed-tags-in-put-and-write-them-only-through-store-transactions]]
