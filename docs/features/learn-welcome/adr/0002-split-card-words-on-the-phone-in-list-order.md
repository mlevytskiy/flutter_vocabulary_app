---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
ticket: "learn-welcome"
---

# 0002 — Split card words on the phone in list order

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

Stories need groups of words; an AI grouping answers too slowly for the flow (owner, 2026-10-30).

## Decision drivers

- AC-06
- NFR-02
- owner: in order, smaller groups allowed, other-source tail moves on

## Considered options

1. Pure in-order split with the source-tail rule (chosen)
2. AI grouping (`POST /story/group`)
3. Reuse saved `WordGroup`s

## Decision outcome

Chosen: Option 1. `splitGroups(words)`: take up to 12 in order; if the trailing run of words from one source differs from the word before it and is at most 4 long, cut it to the next group. Source key = `sourceId` or `typed`. The first 3 groups get stories.

## Consequences

- + instant and testable
- − groups do not follow meaning; stories may mix themes
