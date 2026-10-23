---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0002 — Move a session's boxes in one store transaction at the end

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

AC-13 requires one move per word per session and AC-16 requires that a left session writes nothing. Writing after each page would need undo on leave.

## Decision drivers

- AC-13, AC-16
- §6 NFR: box writes for a whole session commit together or not at all

## Considered options

1. One `CollectionStore.update` with a pure `applySession` at the end (chosen)
2. Write each word as its ladder completes, roll back on leave
3. Keep a pending session record and commit on finish

## Decision outcome

Chosen: option 1. The session keeps outcomes in memory; on the last page it calls `store.update(id, (c) => c.boxes = applySession(c.boxes, outcomes, now))`. `applySession` is pure and unit-tested; it also drops boxes whose row is gone.

## Consequences

- + trivially all-or-nothing; leaving or a crash writes nothing (no resume, by owner decision)
- + `update` already guards filing and protected fields
- − a session's progress is lost if the app is killed (accepted by the owner)
