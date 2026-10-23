---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0004 — Play sessions from a pure ladder queue in one session notifier

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

The word-ladder order (B2) with misses reinserted 3 pages later, step draws and due-first ordering are the riskiest logic in the feature.

## Decision drivers

- AC-08, AC-09, AC-14
- testability: deterministic with a seeded Random

## Considered options

1. Pure `LadderQueue` + `LearningSession` notifier owning pages and outcomes (chosen)
2. Put the ladder logic in the screen's State
3. Precompute the whole page order up front

## Decision outcome

Chosen: option 1. `LadderQueue` (pure Dart) holds each word's rung, miss flag and a pending list; `next()` returns the word and rung to show; `record(rowId, right)` moves rungs and reinserts. The notifier maps (word, rung) to an unused page of that step for that word (rotating exercise types; a board page covers its 4 words for Meet), builds the frame state and finishes the session.

## Consequences

- + the hard part is unit-testable without widgets
- + precomputing is impossible anyway because misses change the order
- − pages are prepared for every word × drawn type up front (bounded: ≤ 19 words × ≤ 9 types)
