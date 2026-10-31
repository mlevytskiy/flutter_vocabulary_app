---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0002 — Build the warm-up as a pure plan walked by the Learn flow

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

The warm-up now has 3 or 4 steps chosen by rules (intro only without a level, grammar every ≥ 4 finished warm-ups, never both, not when the talk limit is reached). Today the LearnFlow notifier holds the two-question warm-up (learn-welcome ADR-0001).

## Decision drivers

- Spec AC-02, AC-03, AC-06, AC-07, AC-08: rules that must be unit tested
- Reuse of the LearnFlow notifier and its warmUp phase
- Spec §6: 3 or 4 steps

## Considered options

1. **A pure `planWarmUp` function** builds the step list; the LearnFlow notifier walks it.
2. **A new WarmUp notifier** that hands its answers to LearnFlow.

## Decision outcome

**Chosen:** Option 1. The rules live in one pure, tested function; the notifier keeps one phase and one place for leaving; no second notifier to keep in sync.

## Consequences

Good: the plan is tested without widgets. Bad: the notifier file grows; warm-up helpers move to `warm_up_plan.dart` to keep it readable.
