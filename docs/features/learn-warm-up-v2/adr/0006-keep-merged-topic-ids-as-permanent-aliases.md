---
status: Accepted
owner: "Architect (Claude Opus 5.5)"
reviewers: ["Tech Lead"]
updated_at: "2026-10-31"
feature_size: "M"
ticket: "learn-warm-up-v2"
---

# 0006 — Keep merged topic ids as permanent aliases

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Architect (Claude Opus 5.5); Fable 5.1 owner proxy (delegated by the owner), design batch D-a…D-g

## Context

The revised catalog merges 6 pairs and adds 6 topics. Older app builds may still hold the merged-away ids.

## Decision drivers

- Spec AC-14: groups and an example situation per topic
- Spec AC-15: older versions keep working with no end date
- The talk start uses the topic text; the id is only logged

## Considered options

1. **`topics.ts` gets `group` and `hook` and an alias map** for the 6 old ids, used wherever an id is read or logged; the app's bundled 3 stay first.
2. **A separate JSON catalog served to the app.**

## Decision outcome

**Chosen:** Option 1. The catalog stays one constant next to its tests; nothing in the app changes for it.

## Consequences

Good: no app change for the catalog. Bad: the alias map must never be removed (a test pins it).
