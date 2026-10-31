---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0004 — Enforce the profile topic slot in Worker code

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

Topics must be ranked by the words, with at most one topic there because of the profile (G2), and each topic needs a one-line situation in the learner's mood and level.

## Decision drivers

- Spec AC-13: words decide; ≤ 1 profile topic; situation ≤ 20 words
- Devil's advocate: a cheap model drifts toward work topics
- Spec §6: 4 s, one topic call

## Considered options

1. **The model returns word-fit ids, at most one profile id and situation lines; Worker code builds [word1, word2, profile-or-word3]**; keyword fill unchanged; a failed line uses the catalog hook.
2. **The model ranks everything**; the profile rule is only an instruction.

## Decision outcome

**Chosen:** Option 1. The rule is tested in code, and one call still returns everything.

## Consequences

Good: testable G2. Bad: a longer prompt and output (raise the output cap); the 3 s server timeout stays.
