---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0001 — Keep the learner profile in one preferences value

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

The warm-up must remember the level, goal and daily context, which main question comes next, how many warm-ups finished since the grammar question, and how many talks reached results since the last 👍/👎. CLAUDE.md rule 5 forbids a new domain model without approval.

## Decision drivers

- Spec AC-12: the profile stays on the phone; AC-11: change and clear in one place
- CLAUDE.md rule 5: no new domain model; `shared_preferences` is approved
- Spec AC-04: no overwrite by a blank or 1–2 character answer

## Considered options

1. **One JSON value in preferences** behind a `LearnerProfileStore` and a provider.
2. **Separate preference keys** per field.
3. **An Isar record**: a new domain model that needs the owner's approval.

## Decision outcome

**Chosen:** Option 1. One read at the start and one write per answer; clearing a field is one write; no approval needed; the store never throws and reads a bad value as empty.

## Consequences

Good: simple, testable with a fake store. Bad: a reinstall wipes it (accepted, spec §11). The value carries a version number for later changes.
