---
status: draft
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan from learn-part-step-1 §1)"
---

# Match word and definition

## Goal
Stage 1 (passive). The learner links each English word to its English definition. This builds recognition without the native language.

## One round
- The app takes up to 6 words that have a definition.
- The screen shows the words in one column and the shuffled definitions in the other.
- The learner links word to definition. A wrong link counts a miss.
- The round ends when all are linked. TTS can read a word or definition on tap-and-hold.
- A summary lists words with misses.

## What it uses
- The row's `definition` field (already in the app). Rows without one get a definition from the Worker's define endpoint (`define.ts`).
- Board widget of Match synonyms.
- TTS (optional). Shared page: no.

## Result
Per word: misses in this round. Nothing saved to the word.

## People
App only in v1.

## Acceptance criteria
- Given a group where a row has no definition, when the round is built, then the definition is fetched or the row is skipped.
- Given a right link, when tapped, then both items lock.
- Given a wrong link, when tapped, then a miss is counted for the word.
- Given the learner holds a card, when TTS is on, then the text is read aloud.
- Given the round ends, when the summary opens, then it lists words with misses.

## Open questions
- Long definitions do not fit a card. Cut to the first sentence?
- Should a word with only a translation (no definition) use the translation instead?
