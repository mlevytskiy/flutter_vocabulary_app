---
status: draft
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 2); learn-part-step-1 §1"
---

# Pick the right answer

## Goal
Stage 1 (passive). The learner picks the right word or meaning from 4 options. This is recognition, so it fits Stage 1.
**Proposed move: Stage 2 → Stage 1**, because choosing from options is not producing the word.

## One round
- The app shows a definition (or translation) and 4 words, or a word and 4 meanings.
- The learner taps one option.
- The app shows right or wrong at once and the right answer.
- Wrong options come from other words of the session, so no AI is needed.
- After the last word, a summary lists the words missed.

## What it uses
- Words, translations, definitions of the session; the group for the pool of wrong options.
- AI: none. TTS optional. Shared page: no.

## Result
Per word: right or wrong on first try. The same question builder feeds the Quiz (Step 3).

## People
App only in v1.

## Acceptance criteria
- Given a session with at least 4 words, when a question shows, then it has 4 different options with one right.
- Given a session with fewer than 4 words, when Start is pressed, then the exercise says it needs 4 words.
- Given a tap, when the option is wrong, then the right option is shown.
- Given the last question, when answered, then a summary lists the missed words.

## Open questions
- Does the owner accept the move to Stage 1?
- Direction: word → meaning, meaning → word, or both mixed?
