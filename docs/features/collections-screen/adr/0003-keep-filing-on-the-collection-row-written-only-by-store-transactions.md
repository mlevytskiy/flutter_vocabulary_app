---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0003 — Keep filing on the collection row, written only by store transactions

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

A collection needs a name, a folder, a place in its level's order, a bin mark and a "kept" flag (AC-01, AC-13–AC-14, AC-19–AC-22). Today every writer saves through `SessionStore.put`, a whole-record upsert from the caller's copy (`session_store.dart:113-151`). The main screen's autosave, the story tracker, word grouping and dialogue push each hold a copy for a while, so a rename or move made meanwhile would be silently reverted, and a collection erased for good would be re-created by the next save. The spec makes this a hard requirement (AC-27, "Name and place stability").

## Decision drivers

- Quality goal 1 / spec §6: 0 reverted names, places or orders, and 0 collections coming back from the bin, over 100 scripted runs.
- Spec §1: the approved new data is the collection's name, its folder and its place in the order, the folders and the recycle bin entries.
- Precedent: `results` is already protected inside `put()` (learn-kit S-22).
- Quality goal 3: one query should give Collections, History and the launch rule what they need.

## Considered options

1. **Fields on the collection row, protected in `put()`** — `name`, `folderId`, `order`, `binnedAt`, `binnedFromFolderId`, `keep` on `WordCollection`; `put()` copies them from the stored record, never from the caller; dedicated transactions write them.
2. **A separate Isar collection for placement** — `CollectionPlace` keyed by collection id holds the same fields; the collection record is untouched.

## Decision outcome

**Chosen:** option 1. It follows the `results` precedent, keeps one record per collection (no orphans to reconcile), and lets every list read one query. Option 2 gives the protection by construction, but every list joins two collections, an erase must keep both in step, and it would still need the "never re-create" rule.

The rules:
- `put()` takes the filing fields from the stored record, and **does nothing when no record with that id exists**. Only `CollectionStore.create()` inserts (first launch, "New collection").
- `rename`, `move`, `reorder`, `bin`, `restore`, `erase` and `sweepBin` are each one Isar write transaction that reads the stored records, checks the invariants (the current collection cannot be binned, a folder cannot go inside itself) and writes only filing fields. They are not debounced (QG-4).
- The default name is stored as text at creation ("16.10.2026 14:30", local time). The one-time backfill on store open names existing collections from the timestamp inside their id, or from their earliest stored date (AC-04), puts them at the top level and orders them oldest first.
- `keep` is set by New collection, rename, move, reorder and the first word (AC-19).

## Consequences

**Positive**
- No writer can revert filing or resurrect an erased collection through `put()`.
- Collections, History and the launch rule read one collection with a filter.

**Negative**
- The protection depends on `put()` staying disciplined; every filing field needs a test that a stale `put()` leaves it alone.
- The main screen's in-memory copy may show a stale name until it re-reads; the title therefore watches the stored name, not the notifier's copy.

**Neutral**
- Moving to a separate collection later is possible with a one-time copy of six fields.

## Links

- Spec: [[../spec.md]] AC-01, AC-03, AC-04, AC-14, AC-19, AC-27; §6 "Name and place stability"
- SAD: [[../sad.md]] §4, §5, §8
- Related ADR: [[0005-mark-a-deleted-item-in-place-and-let-a-binned-folders-contents-follow-it]], [[0006-deliver-late-results-into-their-own-collection-through-an-atomic-store-update]]
