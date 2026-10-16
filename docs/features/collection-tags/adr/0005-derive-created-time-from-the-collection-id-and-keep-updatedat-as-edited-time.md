---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0005 — Derive created time from the collection id and keep updatedAt as edited time

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

The Collections filter needs a created time and an edited time (US-07). `WordCollection` has no created field. Its id starts with the creation moment, which `creationMomentOf` (`collection_name.dart:43`) already decodes for default names and History. `updatedAt` moves on word changes and on Notes-page tag edits today, and it is the published time. The owner decided that Edited = `updatedAt`, moved by any saved change including name, description or tags (AC-06, C1), and that Created = the id's moment, falling back to `updatedAt` (AC-25, C7).

## Decision drivers

- Created must agree with what the default name shows (failure-mode V4).
- No backfill and no new stored field when the data already exists (rule 5).
- Edited keeps today's meaning, so History order and the reopen rule behave as before (C1).

## Considered options

1. **Derive Created from the id on read; Edited = `updatedAt`.**
2. **A stored `createdAt`**, backfilled once from the id and written by `create()`.

## Decision outcome

**Chosen:** option 1. It is exact for every collection, old and new, has nothing to migrate and can't drift. Option 2 duplicates the id's information and adds a backfill. The owner allowed it only as a cache, and it isn't needed.

`setDetails` moves `updatedAt` and `lastLocalModifiedAt` only if the name, description or a tag list changed. Rename through the store keeps its no-move rule (C1). Date ranges are computed in local calendar days by a pure function (AC-37).

## Consequences

**Positive**
- Created always matches the name and History.

**Negative**
- Every summary decodes the id (cheap, base36 prefix).

**Neutral**
- If ids ever stop carrying a moment, the fallback is `updatedAt`.

## Links

- Spec: [[../spec.md]] AC-06, AC-20b, AC-25, AC-37
- SAD: [[../sad.md]] §4, §8
