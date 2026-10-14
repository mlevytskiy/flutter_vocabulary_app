---
status: clarified
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 2, moved to Stage 1); learn-part-step-1 §1"
---

# Pick the right answer

## Goal
Stage 1 (passive). The learner picks the right answer from 4 options. Choosing is recognition, so the exercise is Stage 1 (moved from Stage 2; at implementation `exercises.dart` changes `stage: 2` to `stage: 1`).

## One round
- A round has 3 to 9 words (D-13); a bigger group is split evenly, never a round under 3. One question per word, in group order.
- Two question kinds alternate, starting with kind A: **A** shows the English word, options are 4 translations. **B** shows the meaning, options are 4 English words. The meaning is the row's stored definition (the word hidden as "___", D-08); if empty, its translation. No network call.
- The 3 wrong options come from other words of the group. If the group has fewer than 3 others, the pool is topped up from the learner's other words. Wrong options are never equal (ignoring case and spaces) to the right option or to each other. The right option sits in a random place.
- A word with no translation (or no usable wrong options) gets no question and is left out. If fewer than 3 words remain, the screen says "Not enough words for this exercise" with Back. The whole word list must give at least 4 different options.
- The learner taps one option. The first tap is final: the right option turns green; a wrong tap also turns red; then Next. No second try.
- After the last question, a summary lists each word as right or missed, then Next round or Done.

## What it uses
- Word, translation and definition of each row; the learner's other words as the wrong-option pool.
- AI: none. TTS: none in v1. Shared page: no.
- One pure question builder (see Decisions), shared with the Quiz.

## Result
Per word: right (1) or missed (0), first tap only. On screen in the summary; nothing is saved (D-04, D-12).

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a group of 5 words with translations, when a question shows, then it has 4 different options and exactly one is right.
- Given kind A, when the round runs, then odd-numbered questions show the word with translations; even-numbered show the meaning with words.
- Given a wrong option that equals the right one ignoring case, when options are built, then it is replaced by another word.
- Given a group of 3 words and a word list of 10, when options are built, then wrong options come from the other 7 words too.
- Given fewer than 3 words with usable questions, when the exercise opens, then "Not enough words" shows and no round starts.
- Given a wrong tap, when it lands, then the tapped option is red, the right one green, and the answer cannot change.
- Given a definition containing its own word, when shown, then the word reads "___".
- Given the last question answered, when the round ends, then the summary lists every word as right or missed.

## Decisions
- Move to Stage 1: yes; choosing is recognition. README row updated. (agent, 2026-10-14)
- Direction: both kinds, alternating A/B by position, so the order is testable. (agent, 2026-10-14)
- Meaning for kind B: stored definition, else translation; no /define call, since this exercise needs no AI. (agent, 2026-10-14)
- Wrong options: group first, then the learner's other words; no AI, no invented words. (agent, 2026-10-14)
- Builder contract: `buildQuestion(word, pool, kind, random)` is pure (no I/O, no state). It returns prompt text, 4 distinct options, the right index and the word id, or null if 4 distinct options cannot be made. The Quiz passes its own kind and random; the same input and seed give the same question. (agent, 2026-10-14)
- One tap is final; wrong shows the answer. Matches "right on first try". (agent, 2026-10-14)

## Open questions
- Owner: should the Quiz be allowed to skip alternating and pick kinds freely? Default now: yes, kind is the caller's choice.
