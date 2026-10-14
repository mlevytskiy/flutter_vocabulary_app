---
status: draft
stage: 2
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart; screenshot ai-chat-exercise-menu (Flashcards) MERGED here"
---

# Remember or not (flashcards)

**Merged:** the screenshot's "Flashcards (word → meaning → word)" is this exercise.

## Goal
Stage 2 (active). The learner sees the meaning, tries to recall the word, then flips the card and says if they remembered it.

## One round
- The card front shows the translation or definition (not the word).
- The learner tries to say or think of the word, then taps Flip.
- The back shows the word, an example and a TTS button.
- The learner taps "Remembered" or "Not yet".
- "Not yet" cards come back at the end of the round, once.
- Optional second pass: word on the front, meaning on the back.

## What it uses
- Words, translations, definitions; TTS. AI: none. Shared page: no.

## Result
Per word: remembered or not on the first pass. It is self-rated, so it is a hint for Step 3, not proof.

## People
App only in v1.

## Acceptance criteria
- Given a group, when the round starts, then cards are shuffled and show the meaning side first.
- Given Flip, when tapped, then the word and the TTS button show.
- Given "Not yet", when tapped, then the card returns once at the end.
- Given all cards are done, when the round ends, then the summary shows counts of remembered and not yet.

## Open questions
- Is the word → meaning pass in this exercise or left to Stage 1?
- Do "remembered" marks ever feed the Step 3 result?
