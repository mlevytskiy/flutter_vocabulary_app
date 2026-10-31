---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0005 — Judge grammar per reply inside the talk call

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

With a grammar focus the results show "Rule: used N times, M right" from judgements the AI is sure about. The rule is invited, never required (spec §1).

## Decision drivers

- Spec AC-09, AC-10: invite, gentle fix, count right/wrong only
- Spec §6: no extra AI calls beyond the reactions and the topic pick
- Proxy D-e: the rule list lives in the app

## Considered options

1. **The talk start carries the rule text; each reply returns `grammarVerdict` right / wrong / unsure** for the learner line it answers; the app counts.
2. **A separate judging call at the end of the talk.**

## Decision outcome

**Chosen:** Option 1. No extra call or wait; the verdict comes with the reply the talk already makes.

## Consequences

Good: cheap. Bad: verdicts on recognised speech are noisy; unsure is never counted, and the line hides when nothing was judged.
