---
status: clarified
stage: 2
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 2, guess the word in context)"
---

# Fill the gaps

## Goal
Stage 2 (active). The learner types the missing word in a sentence. They must produce the word, not just recognise it.

## One round
- A round has 3 to 9 words (D-13), group order. A word with no usable sentence is left out; fewer than 3 left shows "Not enough words for this exercise" with Back.
- The sentence has one gap ("___", D-08). The translation shows under it as a hint. The phone keyboard opens at once; no autocorrect or suggestions; Send submits.
- Matching follows D-18. Right: green, the full sentence shows, Next. Almost (one typo): counts as right, the correct spelling shows.
- Wrong: the first letter and the letter count show ("r _ _ _ _ _ _"), and the learner may try once more. A second wrong ends the word: the answer shows, result "missed". A "Show answer" button also ends it as missed.
- After the last word, a summary lists each word as 1st try, 2nd try or missed, then Next round or Done.

## What it uses
- Sentence, first match wins: (1) a line of a dialogue linked to the word (`FilmDialogue.wordRowIds`) that contains the word as a whole word; (2) else one short simple sentence from the Worker, one call per group, cached there (D-03, D-06). Photo context is not used.
- If the word appears twice in a sentence, all are gaps masked as one "___" each and the sentence is rejected (it must have exactly one). A line is cut to its one sentence around the word.
- Word, translation. TTS: none in v1. Shared page: no.
- Data load fails: D-05 (error line, Retry).

## Result
Per word: right on 1st try (2), right on 2nd try (1), missed (0). Summary only; nothing saved (D-04, D-12).

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a word with a sentence, when the question shows, then the word is "___" and the translation is shown.
- Given "Received" typed for "received", when sent, then it is right on this try.
- Given "recieve" for "receive", when sent, then it counts as right and the correct spelling shows.
- Given a different inflected form ("walked" for "walk"), when sent, then it is wrong and the first letter shows with one more try.
- Given a wrong first try then the right word, when sent, then the result is "2nd try"; given two wrong, then "missed" and the answer shows.
- Given a dialogue line with the word and a Worker sentence, when the sentence is chosen, then the dialogue line is used.
- Given a sentence where the word still appears after masking or twice, when it is made, then it is rejected and the next source is tried.
- Given the last word answered, when the round ends, then the summary lists each word's result.

## Decisions
- Sentence source: dialogue line first (free, in context), else Worker. No photo text. (agent, 2026-10-14)
- Checking: D-18 (typed-answer matching rules, shared). (agent, 2026-10-14)
- Inflected forms are wrong, not accepted: the exercise tests the exact stored word. The stored form is also what the gap hides. (agent, 2026-10-14)
- Hint is the translation, plus the first letter and length after a miss. No separate hint button. (agent, 2026-10-14)
- One retry only, as before; "Show answer" is allowed and scores 0. (agent, 2026-10-14)
- Multi-word entries ("give up"): the gap covers the whole phrase; same rules apply. (agent, 2026-10-14)

## Open questions
- Owner: should a word with a typo ("almost") score less than a perfect 1st try? Default now: no, equal.
