---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0007 — Count with a fixed-list events call

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

The owner wants counts of warm-up parts shown, answered and left, topics, finished talks and 👍/👎 (D7). Leaving the warm-up and 👍/👎 happen without any existing call.

## Decision drivers

- Spec AC-16, AC-17: fixed values and numbers only
- Spec §6.1: no content in logs
- No account: counts are per event, not per person

## Considered options

1. **A new `POST /learn/events` call** taking ≤ 20 events from a fixed list, sent fire-and-forget; anything else is rejected; the Worker only logs.
2. **Log only what existing calls see**: cannot count leaving or 👍/👎.

## Decision outcome

**Chosen:** Option 1. It is the only option that measures the KPIs, and the fixed list keeps content out by construction.

## Consequences

Good: KPIs measurable from logs. Bad: a lost batch is lost (fire-and-forget, accepted).
