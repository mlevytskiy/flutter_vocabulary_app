---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
ticket: "learn-welcome"
---

# 0006 — One self-check card and one set of rating rules

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

Self-check Cards (tasks only, 2026-10-27) plans a flip card with four ratings after mistakes in exercises; the Learn flow needs the same card for every word (owner A15: merge).

## Decision drivers

- AC-07, AC-08
- self-check-cards AC-03 – AC-07

## Considered options

1. Build the card and rules here; self-check-cards reuses them (chosen)
2. Two widgets

## Decision outcome

Chosen: Option 1. `self_check.dart` (rules) and `self_check_card.dart` (widget) and `WordBox.lastCheckSide` are built by learn-welcome; self-check-cards keeps only its scheduling in exercise sessions, the hint reporting, the results line and the talk quick check, and depends on these tasks.

## Consequences

- + one card everywhere
- − self-check-cards waits for learn-welcome T2–T3, T11
