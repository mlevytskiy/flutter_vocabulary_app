---
status: draft
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart; screenshot ai-chat-exercise-menu (Speaking/writing practice) MERGED here"
---

# Make your own sentences

**Merged:** the screenshot's "writing practice - you write 5 sentences, I fix them" is this exercise.

## Goal
Stage 3 (examine). The learner writes a sentence for each word with no scaffold. The AI score says if the word is known or needs repeating.

## One round
- The app shows a word (English only, no translation).
- The learner writes one sentence with it.
- The Worker's AI scores 0–3: wrong use, weak, right with errors, right.
- It shows one line of reason and the fixed sentence.
- Random order over the group, no second chance.

## What it uses
- Group words. AI on the Worker: one call per sentence. Shared page: no.

## Result
Per word: score 0–3 and date. 3 = known; 0–1 = repeat; 2 = stays in queue. This is the Step 3 record (see README).

## People
App only in v1.

## Acceptance criteria
- Given a word, when shown, then no translation is visible.
- Given a sentence, when sent, then a score 0–3 and one reason line show.
- Given a sentence without the word, when sent, then the score is 0.
- Given the round ends, when the summary opens, then words are listed as known or repeat.
- Given the AI call fails, when sent, then the learner can retry and no score is saved.

## Open questions
- Where is the per-word result stored? A new record needs owner approval (CLAUDE.md rule 5).
- Do we show a hint (first letter of a word form) after a long wait?
