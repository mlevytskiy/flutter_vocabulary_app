---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0003 — Add a free reaction call with a fixed-line fallback

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

After the intro, main and grammar answers the AI adds one short line. The talk call counts against the 20 talks a day and is built for missions.

## Decision drivers

- Spec AC-05: ≤ 15 words, 2 s, fixed line, never counted
- Spec §6: ≤ 2 reaction calls per Learn
- Spec §6.1: prompt injection in own answers

## Considered options

1. **A new `POST /learn/warm-up/reaction` call**: cheap model, 1.8 s server cutoff, checked reply, free.
2. **Reuse `/learn/talk`**: counts against the daily allowance and carries mission fields.

## Decision outcome

**Chosen:** Option 1. It is free as the owner chose (Q5), small, and returns an empty reaction rather than an error, so the app shows the fixed line.

## Consequences

Good: the warm-up never waits more than 2 s. Bad: one more route to keep; bounded by ≤ 2 calls per Learn, no rate limit needed.
