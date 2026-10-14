---
status: clarified
stage: 3
updated_at: "2026-10-14"
source: "screenshot ai-chat-exercise-menu (Quiz: 5-7 questions, multiple choice and fill-in-the-gap)"
---

# Quiz

## Goal
Stage 3 (examine). A short mixed test over the group's words. Each examined word gets one label: known or repeat (D-31).

## One round
- The quiz asks `n = min(7, usable words)` questions, one per word. Usable = the word gets at least one question type (below). Which words: a random sample of the group (no history exists, D-33), then shuffled. A group of 5 or 6 usable words asks all of them; 7 or more asks 7. Fewer than 3 usable words shows "Not enough words for this exercise" with Back.
- Question type per position (1-based): odd = multiple choice, even = fill the gap. Choice questions alternate kind A, kind B (D-14), starting with A. A word with no usable sentence gets choice; a word where `buildQuestion` returns null gets a gap; if neither works it is left out.
- Choice: 4 options, builder and distractors as in Pick the right answer (D-14, D-15). Gap: sentence with "___" and the translation as the cue, sentence source D-20, matching D-18 (as in Fill the gaps).
- Exam rules (D-34, D-41): no hint, no first letter, no speaker, no retry, no "Show answer". The first tap or Send is the answer and is locked. Nothing shows right or wrong until the summary. A Skip button is on every question and counts as repeat. Next appears after the answer or Skip.
- Summary: "N of n known", then each word as known or repeat; for repeat words it shows the right answer and the learner's answer. Then Done, or "Repeat" if any word is repeat.
- "Repeat" starts a new quiz of only the repeat words, in the same rules; this round may have 1 or 2 words (the 3-word minimum does not apply). Its labels replace the earlier ones on screen.

## What it uses
- Builders of Pick the right answer (`buildQuestion`) and Fill the gaps (sentence source, matching). Word, translation, definition, the learner's other words.
- AI: the Worker only for gap sentences, one call per group (D-03). If it fails, the quiz runs with choice questions only and shows one line "Gap questions are unavailable"; no Retry needed. Shared page: no.

## Result
Per word: known = right on the first and only answer (an "almost", D-18, counts as right); repeat = wrong, skipped or left blank (D-32). A word never asked has no label. Shown in the summary only; not saved (D-33).

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a group of 9 words with translations, when the quiz starts, then it asks 7 questions on 7 different words, odd ones choice and even ones gap.
- Given a group of 5 usable words, when it starts, then all 5 are asked; given 2 usable words, then "Not enough words" shows and no quiz starts.
- Given an answer is tapped or sent, when the next question shows, then no right or wrong has been shown and the earlier answer cannot be changed.
- Given a wrong gap answer, when it is sent, then there is no second try and no first-letter hint.
- Given "recieve" for "receive", when sent, then the word is known in the summary.
- Given Skip on a question, when the summary opens, then that word is repeat.
- Given the quiz ends with 2 repeat words, when "Repeat" is tapped, then a quiz of exactly those 2 words starts.
- Given the Worker is unreachable, when the quiz starts, then all questions are choice and the one-line note shows.

## Decisions
- Question count: `min(7, usable)`, at least 3; the "5" in the screenshot is a floor only for groups that have 5. (agent, 2026-10-14)
- Word choice: random sample; "words that did badly first" is dropped because nothing is saved (D-33). (agent, 2026-10-14)
- Kind mix: fixed alternation by position so tests are repeatable; the caller picks the kind (D-42). (agent, 2026-10-14)
- Typed question is an exam question: no retry (D-41). (agent, 2026-10-14)
- Gap shows the translation as its cue (the spec lists it, so D-34 allows it): without it many words fit a gap. (agent, 2026-10-14)
- Repeat round is a fresh quiz of the repeat words; no 3-word minimum. (agent, 2026-10-14)
- Worker failure degrades to choice-only instead of blocking an otherwise offline exercise (narrows D-05 for Quiz). (agent, 2026-10-14)

## Open questions
- Owner: should known/repeat be saved so a later quiz can start with repeat words? Needs a record (rule 5, D-33). Default now: no.
- Owner: should "Repeat" labels replace the first quiz's labels once saving exists? Default now: yes, the last quiz wins.
