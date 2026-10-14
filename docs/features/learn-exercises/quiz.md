---
status: draft
stage: 3
updated_at: "2026-10-14"
source: "screenshot ai-chat-exercise-menu (Quiz: 5-7 questions, multiple choice and fill-in-the-gap)"
---

# Quiz

## Goal
Stage 3 (examine). A short mixed test over the words. It gives each word a result: known or repeat.

## One round
- The app picks 5–7 words, with words that did badly before first.
- Each gets one question, mixed: multiple choice (from Pick the right answer) or fill the gap (from Fill the gaps).
- No hints. Right or wrong is shown only at the end.
- The app puts each word in "known" or "repeat".
- "Repeat" words can start a short round at once.

## What it uses
- Question builders of Pick the right answer and Fill the gaps (build them once). Words, translations, definitions.
- AI on the Worker only for gap sentences (cached). Shared page: no.

## Result
Per word: right or wrong, question type, date. Known = right; repeat = wrong. This is the Step 3 record.

## People
App only in v1. Later: one quiz to the table, each person answers on their phone.

## Acceptance criteria
- Given a group, when the quiz starts, then 5–7 questions of two types show.
- Given the learner answers, when the next question shows, then the answer is not revealed yet.
- Given the quiz ends, when the summary opens, then each word shows known or repeat.
- Given fewer than 5 words, when started, then each word gets one question.
- Given "Repeat" is tapped, when it opens, then only the repeat words are in the round.

## Open questions
- Is one wrong answer enough for "repeat", or two quizzes?
- Where is the result stored? A new record needs owner approval.
