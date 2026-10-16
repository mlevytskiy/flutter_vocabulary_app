---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0002 — Rename Session to WordCollection with stored names pinned

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

The owner decided that "collection" replaces "session" in the app's code as well as its text, while stored records, Worker routes and shared links keep their names (spec §1, decision 1). About 98 files in `lib/` mention session and 31 use the class `Session`. The obvious name `Collection` cannot be used: `isar_community` already exports an annotation class `Collection` and a schema type `CollectionSchema`, and the generated `const CollectionSchema = CollectionSchema(...)` would not compile.

## Decision drivers

- Quality goal 2 / spec §6 "Update safety": 0 words, photos, notes, stories or exercise results lost when moving to the updated app.
- Spec §1 decision 1: stored names stay; Worker addresses and given links stay.
- §2 constraint: Isar keys stored collections and properties by name; `@Name` pins them (precedent: `SessionSource` stored as `SourcePhoto`).

## Considered options

1. **`WordCollection`** — class `WordCollection`, field `collectionId`, `CollectionStore`, `collectionStoreProvider`, `collectionByIdProvider`, files `word_collection.dart`, `collection_store.dart`.
2. **`VocabCollection`** — the same, with the repo's `vocab` prefix (beside the older, unrelated `VocabWord`).

## Decision outcome

**Chosen:** option 1, `WordCollection`. It reads naturally, clashes with neither Isar nor `dart:collection`, and is not confused with `VocabWord`.

How it is done:
- `@Name('Session')` on the class and `@Name('sessionId')` on `collectionId` (and on every other renamed stored field, including `StoryRun.sessionId`), so the Isar schema keeps its stored names and old records open unchanged.
- `shared_preferences` key strings (`current_session_id`) and the Worker's routes and JSON field names stay as they are.
- The rename is the first implementation step, mechanical, with no behaviour change and every existing test green, before any filing field is added.

## Consequences

**Positive**
- One word for one thing in code and in text.
- A data problem in the release can come only from the pin or from the filing backfill, and the rename step is tested alone first.

**Negative**
- A large diff that collides with any parallel branch.
- The Isar accessor becomes `isar.wordCollections`, and stored names now differ from Dart names, so a future reader must look at `@Name`.

**Neutral**
- Specs and SADs written before this feature keep saying session; CONTEXT.md records the old name.

## Links

- Spec: [[../spec.md]] §1 decision 1, US-14, AC-04, AC-33
- SAD: [[../sad.md]] §4, §11
- Related ADR: [[0003-keep-filing-on-the-collection-row-written-only-by-store-transactions]]
