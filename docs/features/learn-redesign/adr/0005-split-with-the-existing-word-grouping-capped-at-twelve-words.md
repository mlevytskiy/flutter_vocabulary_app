---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0005 — Split with the existing word grouping capped at twelve words

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

With 20+ words and split on, a session takes one group of 7–12 words. The app already groups words (7–19 per group, AI topical split) for the old learn page and mnemonic stories.

## Decision drivers

- owner assumption 5: groups come from the existing AI grouping, tightened to 7–12
- AC-06, AC-07

## Considered options

1. Change the split range of the existing grouping to 7–12 (chosen)
2. Keep 7–19 groups and cut them into chunks of ≤ 12 locally
3. A second, separate grouping for sessions

## Decision outcome

Chosen: option 1. `maxGroupSize` for a split becomes 12 (the threshold to split stays 'more than 19 words'). A stored grouping with any group over 12 counts as stale and regroups once. The Worker's grouping prompt and validation take the new maximum. Story and dialogue groups follow the same groups.

## Consequences

- + one grouping for stories, the old learn page and sessions
- − collections grouped before regroup once (story runs keep their own stored text)
- − the Worker grouping validator changes; its tests update
