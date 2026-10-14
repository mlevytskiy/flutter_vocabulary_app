---
status: clarified
stage: 1
updated_at: "2026-10-14"
source: "Fable ideas (fable-ideas.md §1)"
---

# Guess my word

## Goal
Stage 1 (passive). The learner finds the word from a short English description. Each clue is a new way to meet the word.

## One round
- A round has 3 to 9 words (same split rule as match-synonyms, but up to 9). The grid shows the round's words in a shuffled order, as English words.
- The Worker's AI writes 3 clues per word: clue 1 vague, clue 2 closer, clue 3 almost a giveaway. Simple English, one sentence each. The word shows as "___" in a clue (D-08). Clue 3 may be the stored definition (D-09).
- The screen shows one target at a time: its clue 1 and the grid. Targets come in random order.
- The learner taps a word in the grid. Right on clue 1 scores 3, on clue 2 scores 2, on clue 3 scores 1.
- A wrong tap greys that word out for this target and shows the next clue. A wrong tap on clue 3 greys the word and scores 0 for this target; the answer is then shown and the round moves on.
- A word found as a target stays marked and leaves the targets. Greyed words come back for the next target.
- Words with no usable clues are left out. Fewer than 3 usable words: "Not enough words with clues for this group" and Back. Load error: error line with Retry (D-05).
- The round ends after the last target. The summary lists each word with its score (3, 2, 1, or "not found") and a Next round or Done button.

## What it uses
- Group words; the translation shows on long press of a grid word (never of a clue).
- AI on the Worker: one call per group, cached per word (D-03); sense by the word's translation (D-06).
- Shared page: no (see People).

## Result
Per word: score 0–3 for this round. Shown on screen only; nothing is saved (D-04). Step 3 owns "known / repeat".

## People
App only in v1. The shared page is a published snapshot with no live state, so the buzzer and people-written clues are later steps and need their own spec.

## Acceptance criteria
- Given a group of 6 usable words, when the round opens, then 6 words show in the grid and the first target shows clue 1.
- Given clue 1 and a right tap, when tapped, then the word scores 3 and the next target shows.
- Given a wrong tap on clue 1, when tapped, then that word greys out and clue 2 shows for the same target.
- Given a wrong tap on clue 3, when tapped, then the word greys out, the target scores 0, the answer is shown, and the next target shows.
- Given a clue that contains its own word, when clues are made, then it is shown with "___" in its place.
- Given 12 usable words, when rounds are built, then the rounds are 6 + 6, never a round under 3.
- Given fewer than 3 words with clues, when the exercise opens, then the "Not enough words" message shows and no round starts.
- Given the last target is done, when the round ends, then the summary lists every word with its score.

## Decisions
- Grid is the round's words only (3 to 9), not a fixed 3×3; the grid wraps to fit the phone. (agent, 2026-10-14)
- Each word is a target once; clue 1 resets for every new target. (agent, 2026-10-14)
- A wrong tap after clue 3 scores 0 and reveals the answer; no endless guessing. (agent, 2026-10-14)
- Score is per target and kept on screen only. (agent, 2026-10-14)
- The shared-page buzzer and people-written clues are out of v1; no write-back is built. (agent, 2026-10-14)

## Open questions
- Owner: when the shared page gets live state, should human clues replace the AI clues or sit beside them? Default now: beside.
