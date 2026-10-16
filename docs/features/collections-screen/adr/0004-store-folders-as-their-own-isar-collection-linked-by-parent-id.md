---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0004 — Store folders as their own Isar collection linked by parent id

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

Folders hold collections and folders to any depth (AC-08, AC-13), can be empty, are renamed, moved, reordered among collections, binned with their contents and restored (AC-14, AC-22, AC-24). They live only on the phone (spec §3).

## Decision drivers

- A move, a bin or an erase must change a folder and its collections in one transaction (quality goal 1, QG-4).
- An empty folder must exist (AC-13).
- No new packages; the store already owns an Isar instance (§2).

## Considered options

1. **An Isar collection `CollectionFolder`** — `folderId` (uuid), `name`, `parentId` (null = top level), `order`, `binnedAt`, `binnedFromFolderId`, in the same `vocab` database as collections.
2. **A folder path string on each collection** — no folder records; folders are implied by paths.
3. **One JSON tree in `shared_preferences`** — the whole folder tree as a single value.

## Decision outcome

**Chosen:** option 1. It is the only option that can hold an empty folder (rules out 2) and share a transaction with the collection records (rules out 3, which also rewrites the whole tree on every move). Collections point at their folder by `folderId`; a folder points at its parent by `parentId`.

## Consequences

**Positive**
- A move is a change of one `folderId`/`parentId` plus a renumbering of the level, in one transaction.
- Folders and collections share one `order` space per level, so the grid mixes them in the learner's order.

**Negative**
- One more schema in `Isar.open` and one more generated file.
- Ancestor checks (a folder into itself, "inside a binned folder") walk parent links; fine at the spec's 50 folders.

**Neutral**
- Folder ids are `uuidV4()` from `source_photo_store.dart`.

## Links

- Spec: [[../spec.md]] US-05, US-06, AC-08, AC-13–AC-15, AC-22, AC-24
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0003-keep-filing-on-the-collection-row-written-only-by-store-transactions]]
