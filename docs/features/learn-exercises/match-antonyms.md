---
status: draft
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan from learn-part-step-1 §1)"
---

# Match antonyms

## Goal
Stage 1 (passive). The learner links each word to its opposite. Opposites fix the meaning of the word by contrast.

## One round
- The app takes the words of the current group that have an opposite.
- The Worker's AI gives one clear antonym per word (cached).
- The screen is the same two-column board as Match synonyms.
- The learner links word to antonym. Wrong pairs count a miss.
- The round ends when all pairs are linked. A summary lists words with misses.

## What it uses
- Group words; AI on the Worker for antonyms (one call per group, can share the call with Match synonyms).
- The board widget of Match synonyms (build once).
- Shared page: no.

## Result
Per word: misses in this round. Nothing saved to the word.

## People
App only in v1.

## Acceptance criteria
- Given a group with 3 words that have no opposite, when the round is built, then those words are skipped.
- Given fewer than 3 words with an opposite, when Start is pressed, then the exercise says "Not enough opposites" and goes back.
- Given a right pair, when tapped, then both items lock.
- Given a wrong pair, when tapped, then a miss is counted.
- Given the round ends, when the summary opens, then it lists words with misses.

## Open questions
- Many words (nouns, verbs) have no true opposite. Is "skip them" enough, or use "different from"?
- Merge with Match synonyms into one "Match pairs" exercise with a switch?
