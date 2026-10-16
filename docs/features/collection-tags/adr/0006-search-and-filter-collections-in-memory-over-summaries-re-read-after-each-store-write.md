---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0006 — Search and filter collections in memory over summaries re-read after each store write

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

Search matches name, description and tags by substring, and the filter combines tags (AND), created and edited ranges and four sorts, across all folders, without binned collections (AC-19..AC-24, AC-27, AC-37, AC-38). Results must update ≤ 100 ms after a keystroke with 500 collections (spec §6). Empty collections count (AC-27), unlike `watchHistory`, which keeps only collections with words.

## Decision drivers

- ≤ 100 ms per keystroke at 500 collections / 2,000 tags (QG-2).
- Word-start matching for autocomplete and substring search are awkward to express as Isar queries.
- The pure-rule pattern already used (`filing.dart`, `collection_level.dart`) is easy to unit-test.

## Considered options

1. **A store stream `watchSummaries()`** built on `_watchFiling`. After each write it emits light `CollectionSummary` values for every non-binned collection (empty ones included): id, name, description, origin and topic tags, source tag keys, folder path, tree position, created, edited. A pure `searchCollections(summaries, query, filter, sort)` runs in memory on each keystroke.
2. **Isar queries per keystroke**, with filter conditions on name, description and tag lists.

## Decision outcome

**Chosen:** option 1. Keystrokes never touch the database, the rules live in one pure, timed function, and the same summaries feed the filter sheet's tag counts and the library's live use counts (ADR-0002). Option 2 would split the rules between query code and Dart and still need Dart for word-start matching.

## Consequences

**Positive**
- Fast typing, and all the matching rules are unit-tested in one place.

**Negative**
- After each store write the stream re-reads every record, words included (§11 Low risk). Writes are serialised and debounced by `_watchFiling`.

**Neutral**
- Moving to property queries later only changes `watchSummaries()`.

## Links

- Spec: [[../spec.md]] AC-19..AC-24, AC-27, AC-37, AC-38; §6
- SAD: [[../sad.md]] §4, §5, §10 QG-2
- Related ADR: [[0002-keep-the-tag-library-in-its-own-isar-collection-and-count-uses-live]]
