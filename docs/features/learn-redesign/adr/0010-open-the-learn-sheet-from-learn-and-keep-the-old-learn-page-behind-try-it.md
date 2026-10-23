---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0010 — Open the Learn sheet from Learn and keep the old Learn page behind Try it

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

The owner wants the Learn button unchanged in look and place, but Learn must start learning; every exercise must still open alone.

## Decision drivers

- owner: Learn button the same as now; extra companion button beside it
- AC-01, AC-19; rule 3

## Considered options

1. Learn opens the sheet; `LearnRoute` stays, opened only from Try it with the exercise pre-ticked (chosen)
2. Delete the old Learn page

## Decision outcome

Chosen: option 1. `WordsTableScreen._learn` opens `showLearnSheet` instead of pushing `LearnRoute`. `LearnShareBar` gains a trailing `CompanionButton` right of Learn (layout measuring includes it). `LearnRoute` gets an optional `exercise` query field that pre-ticks it.

## Consequences

- + nothing deleted; old flows keep their tests
- − two ways into exercises (session and Try it)
