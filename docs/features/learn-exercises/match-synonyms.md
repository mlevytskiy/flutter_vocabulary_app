---
status: draft
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan from learn-part-step-1 §1)"
---

# Match synonyms

## Goal
Stage 1 (passive). The learner links each word to a word with the same meaning. This builds recognition of the word and its neighbours.

## One round
- The app takes up to 6 words of the current group.
- The Worker's AI gives one simple synonym per word (cached with the row).
- The screen shows two columns: the words and the shuffled synonyms.
- The learner taps a word, then a synonym. A right pair locks; a wrong pair shakes and counts a miss.
- The round ends when all pairs are linked. A summary lists words with misses.
- A word with no good synonym is left out of the round.

## What it uses
- Words of the group; their translation as a fallback hint (long press).
- AI on the Worker: one call per group for synonyms.
- Shared page: no.

## Result
Per word: number of misses in this round. Stage 1 only; nothing is saved to the word (Step 3 owns "known / repeat").

## People
App only in v1. Later: a table-mate can race on the shared page.

## Acceptance criteria
- Given a group of 6 words, when the round opens, then 6 words and 6 shuffled synonyms show.
- Given a right pair, when tapped, then both items lock and stay linked.
- Given a wrong pair, when tapped, then it is not linked and a miss is counted for the word.
- Given a word with no synonym, when the round is built, then it is skipped, not shown broken.
- Given all pairs linked, when the round ends, then the summary lists words with misses.

## Open questions
- Should the synonym be shown with its translation to help beginners?
- Is a word list of 6 per round right, or all words of the group?
