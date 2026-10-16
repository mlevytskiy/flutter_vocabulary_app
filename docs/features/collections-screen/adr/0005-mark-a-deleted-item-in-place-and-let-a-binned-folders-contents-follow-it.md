---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0005 — Mark a deleted item in place and let a binned folder's contents follow it

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

A deleted collection or folder goes to the recycle bin for 30 days; a folder goes with everything in it as one item, except the current collection, which moves to the folder's old place (AC-20, AC-22). Restore returns an item to its folder, or to the top level if that folder is gone or binned (AC-24). Background work may still finish into a binned collection, and what it produces must be there after a restore (AC-11, AC-27).

## Decision drivers

- Quality goal 1: a binned collection never comes back on its own, and late work is kept for a restore.
- Spec §6 "Bin retention": erased no earlier than 30 × 24 h after deletion.
- One source of truth for what a collection holds.

## Considered options

1. **A mark on the item** — `binnedAt` and `binnedFromFolderId` on the collection or folder; the contents of a binned folder keep pointing at it and are hidden with it.
2. **Separate bin records** — a `BinEntry` with a snapshot of the deleted subtree and where it came from.

## Decision outcome

**Chosen:** option 1. Delete and restore are one small write each, nothing is copied, and late work keeps landing in the one live record. A snapshot (option 2) is a second copy that drifts as soon as a late result arrives, and it is one more new model.

The rules:
- An item is **in the bin** when it or any folder above it has `binnedAt`. Collections, History, the launch rule's fallback and the main screen's pickers all filter on that.
- Only the item the learner deleted carries the mark and appears in the bin; its contents are counted in the confirmation (AC-22).
- Binning a folder that holds the current collection first moves the current collection to the folder's old place, in the same transaction.
- Restore clears the mark; the target is `binnedFromFolderId` when that folder exists and is not in the bin, else the top level.
- Erase (Delete forever, Empty recycle bin, the 30-day sweep) deletes the item and every record under it, then their photo files.

## Consequences

**Positive**
- AC-11 and AC-27 come for free: a binned collection is still a normal record for `update`.
- The 30-day check is one date per bin item.

**Negative**
- Every list must apply the "itself or an ancestor" rule; a missed filter shows a binned collection. `filing.dart` holds the one rule and tests pin it.

**Neutral**
- A collection binned on its own and later inside a binned folder is two bin items; restoring it alone lands at the top level (its folder is in the bin).

## Links

- Spec: [[../spec.md]] US-09, US-10, AC-20–AC-27
- SAD: [[../sad.md]] §4, §5, §10 QG-5
- Related ADR: [[0003-keep-filing-on-the-collection-row-written-only-by-store-transactions]], [[0004-store-folders-as-their-own-isar-collection-linked-by-parent-id]]
