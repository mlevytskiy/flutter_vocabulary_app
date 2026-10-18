---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0003 — Migrate untyped tags once on store open and empty the legacy lists

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

Existing collections and sources hold untyped tags. On the first start after the update they must be sorted into the two kinds: a match with an origin preset (ignoring case) becomes an origin tag, anything else a topic tag. Case duplicates are merged and over-limit data is kept. Source tags are copied up to the collection past the 10 cap, and the library is seeded in collection creation order (AC-17, AC-17b, AC-31, AC-32). The old tags must never come back (AC-18).

## Decision drivers

- 0 lost tags (spec §6 "Migration accuracy").
- ≤ 1 s added to startup for 500 collections, running once (spec §6).
- Precedent: `_backfillFiling` (`collection_store.dart:100-152`) runs from `open()` in one transaction, is idempotent by its own filter, and logs and retries on failure.

## Considered options

1. **One transaction in `CollectionStore.open()`** over every record whose legacy `tags` (or any source's legacy `tags`) is non-empty. It writes the typed lists, upserts library entries and empties the legacy lists in the same write.
2. **Lazy, per record on read**: convert when a record is first loaded.

## Decision outcome

**Chosen:** option 1. It is all or nothing, it can't run twice (the filter is "legacy lists non-empty", which it empties), and every screen (Collections filter, suggestions) sees the migrated state from the first frame. Option 2 leaves half-migrated data: the filter would miss collections nobody has opened yet, and the library seeding order could not follow creation time.

The sorting is pure (`tag_rules.dart`: `sortLegacyTags(legacy, originPresets) → (origin, topic)` plus `mergeCaseDuplicates`) and unit-tested. The store only applies it. Records are visited in creation-moment order (`creationMomentOf ?? updatedAt`) so the library takes the first spelling as AC-32 states. Migration does not move `updatedAt` or `lastLocalModifiedAt`. On failure it logs `VOCAB: tag migration failed` and the next open retries.

## Consequences

**Positive**
- Deterministic and testable over a fixture, and it can't run twice.

**Negative**
- Startup does one extra pass over all records on the first open after the update.

**Neutral**
- The legacy fields stay in the schema, emptied (accepted debt, §11).

## Links

- Spec: [[../spec.md]] AC-17, AC-17b, AC-18, AC-31, AC-32
- SAD: [[../sad.md]] §4
- Related ADR: [[0001-store-typed-tags-as-separate-origin-and-topic-lists-beside-the-legacy-list]], [[0002-keep-the-tag-library-in-its-own-isar-collection-and-count-uses-live]]
