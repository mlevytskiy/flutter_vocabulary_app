---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0005 — Cut the grouped word order into session groups of seven to twelve

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

With 20+ words and split on, a session takes one group of 7–12 words (AC-06). The existing AI grouping makes groups of 7–19, never re-splits story groups, lets dialogue groups be any size, and leaves fewer than 7 left-over words waiting outside every group. Capping it at 12 cannot keep the invariant (13 words cannot be cut into parts of 7–12).

## Decision drivers

- AC-06 (every group 7–12), AC-07 (every word reachable)
- owner assumption 5: groups come from the existing AI grouping
- no regroup of stored groups (stories and dialogues stay)

## Considered options

1. Concatenate the words in AI-group order (waiting words last; row order when grouping is not ready) and cut the whole list with `splitRounds(min 7, max 12)` (chosen)
2. Change the AI grouping's maximum to 12 and regroup stale collections
3. Cut each AI group separately into chunks of 7–12

## Decision outcome

Chosen: option 1. Any list of 14 or more words can be cut into parts of 7–12, and split only shows at 20+, so the invariant always holds; parts follow the AI groups' order, so topics mostly stay together. Option 2 fails for story/dialogue groups and waiting words; option 3 fails for a group of 13 or under 7. The grouping, the Worker and stored groups do not change.

## Consequences

- + no regroup, no Worker change, stories unaffected
- + works even while grouping runs or failed (row order)
- − a session group can straddle two topics
- − the session group is recomputed from the words each time; the "last played" pointer is an index in preferences and shifts when words are added
