---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0006 — Deliver late results into their own collection through an atomic store update

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

A translation, photo reading, Quizlet or subtitle import still running when the learner opens another collection must finish into the collection it started in, even if that collection is by then in the bin, and never appear in the new one (AC-11). Today such a result is dropped (edit-session-from-history ADR-0003; import-from-quizlet: "a result for another session is dropped"). The story tracker, word grouping and dialogue push read a whole copy and `put()` it back later (§2), which races with every other writer.

## Decision drivers

- Spec AC-11 and AC-27; quality goal 1.
- ADR-0003: `put()` no longer writes filing and no longer inserts.
- Isar write transactions are serialised, so a read-change-write inside one transaction cannot interleave with another writer.

## Considered options

1. **`CollectionStore.update(collectionId, change)`** — reads the stored record, applies `change`, writes it, all inside one write transaction; does nothing if the record is gone. Late results and every background writer use it.
2. **A revision check on `put()`** — each record carries a revision; a `put()` from an older copy is refused.

## Decision outcome

**Chosen:** option 1. It delivers the result where it belongs (AC-11) and never throws away the main screen's newer words the way a refused stale `put()` would (option 2 would refuse legitimate autosaves after any background write).

The rules:
- When a result returns for a collection id other than the current one, the notifier calls `update` on that id instead of changing its own state.
- `story_run_tracker.dart`, `word_groups_notifier.dart` and `dialogue_push.dart` move from `byId` + `put` to `update`.
- The main screen's autosave keeps `put()` for the current collection; it can no longer touch filing or re-create an erased record (ADR-0003).
- An erased record makes `update` a no-op, logged as a dropped late result (AC-27).

Supersedes edit-session-from-history ADR-0003 and import-from-quizlet's drop rule.

## Consequences

**Positive**
- No result lands in the wrong collection, and none is lost while its collection exists.
- Background writers stop racing each other.

**Negative**
- Each lookup and import path must carry the collection id it started with; tests for each path that returns after a switch.

**Neutral**
- A result for a binned collection is kept and visible after a restore.

## Links

- Spec: [[../spec.md]] AC-11, AC-27
- SAD: [[../sad.md]] §4, §6 flow 2
- Related ADR: [[0003-keep-filing-on-the-collection-row-written-only-by-store-transactions]]; supersedes edit-session-from-history [[../../edit-session-from-history/adr/0003-ignore-lookup-results-that-return-after-a-switch]]
