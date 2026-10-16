---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0002 — Keep the tag library in its own Isar collection and count uses live

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

Every tag the learner adds is remembered locally, per kind, for suggestions and autocomplete (spec US-04, AC-08, AC-30, AC-35). A tag stays in the library after its last use is removed, and only "Forget this tag" removes it (AC-12, AC-30). Ranking is by how many live (non-binned) collections use the tag, counting its sources once, then by the last time the learner added it (C10).

## Decision drivers

- Counts must never drift from the data. Stored counters go wrong when collections are binned, erased or edited (failure-mode V7).
- Case-insensitive uniqueness within a kind, with the first spelling winning (AC-09, AC-32).
- Autocomplete ≤ 50 ms with 1,000 library tags (spec §6).
- The owner approved one new Isar collection (rule 5, batch 1 and D2).

## Considered options

1. **An Isar collection `TagLibraryEntry`** `{id, kind (TagKind), text, key (lowercase), lastUsedAt, forgotten}`, unique index on (kind, key). Use counts come live from the collection summaries (ADR-0006).
2. **A JSON file in the documents directory** — read into memory at start and rewritten on each change.
3. **An Isar collection with a stored use counter.**

## Decision outcome

**Chosen:** option 1. The unique (kind, key) index enforces first-spelling-wins inside one transaction. It shares the store's Isar instance and transactions, so the migration and `setDetails` can write the collection and the library together, and live counts can't drift. Option 2 has no transactions with the collection writes. Option 3 needs every remove, bin, restore and erase to adjust counters.

Rules: an explicit add (typed, tapped, or copied up from a source) upserts the entry, sets `lastUsedAt = now` and clears `forgotten`. The migration upserts without touching `lastUsedAt` and never clears `forgotten`. Forget sets `forgotten = true`, and presets are never stored unless used. `TagKind` is stored by ordinal (origin = 0, topic = 1), new kinds only appended.

## Consequences

**Positive**
- Counts are always right, and uniqueness is enforced by the database.
- One transaction covers a collection change and its library touch.

**Negative**
- Ranking needs the summaries in memory. The suggestion provider joins library entries with live counts.

**Neutral**
- Forgotten entries stay as rows, so un-forgetting keeps their spelling.

## Links

- Spec: [[../spec.md]] AC-08, AC-09, AC-12, AC-30, AC-32, AC-35
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0006-search-and-filter-collections-in-memory-over-summaries-re-read-after-each-store-write]]
