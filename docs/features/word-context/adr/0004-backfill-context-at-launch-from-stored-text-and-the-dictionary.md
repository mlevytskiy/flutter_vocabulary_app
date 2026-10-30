---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "M"
ticket: "word-context"
---

# 0004 — Backfill context at launch from stored text and the dictionary

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

Old words have no context (B9). Re-analysing photos or downloading subtitles again costs money and may fail (Q12).

## Decision drivers

- AC-12
- NFR-02

## Considered options

1. Background queue at launch: define API for typed/set rows with a definition, stored dialogue lines for film rows, stored full text for photo rows; 20 a minute (chosen)
2. Fill only when a word enters Learn
3. No backfill

## Decision outcome

Chosen: Option 1. `ContextBackfill` starts after the collection autofill, walks rows with empty context and `contextTried == false`, writes found contexts with one `CollectionStore.update` per collection batch, and marks tried rows. A word or definition change clears `contextTried`.

## Consequences

- + no AI cost
- − old photo words stay empty (their full text was never stored)
