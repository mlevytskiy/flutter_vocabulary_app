---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
ticket: "learn-welcome"
---

# 0004 — Save each card rating at once

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

learn-redesign ADR-0002 writes boxes once at the session end; this flow can be left midway and the owner proxy decided ratings are kept (Q17).

## Decision drivers

- AC-08, AC-16

## Considered options

1. One `CollectionStore.update` per rating (chosen)
2. Collect ratings, write at the end

## Decision outcome

Chosen: Option 1. Each rating reads the stored box, applies `rateBox`, writes the box (box, due, `lastUpDay`, `lastCheckSide`) in one update. Exercise sessions keep their end-of-session write.

## Consequences

- + nothing lost on leave
- − up to 36 small writes per session (fine for Isar)
