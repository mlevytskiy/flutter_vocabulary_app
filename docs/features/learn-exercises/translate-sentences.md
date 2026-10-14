---
status: draft
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 3)"
---

# Translate sentences

## Goal
Stage 3 (examine). The learner translates a Ukrainian sentence into English using the target word. The score shows which words can be produced from meaning alone.

## One round
- The Worker's AI writes a simple Ukrainian sentence for each word (the English word is hidden).
- The learner types the English translation.
- The AI scores 0–3: is the word used right and is the sentence good.
- It shows one reason line and a model translation.
- Random order, no second chance.

## What it uses
- Group words, translations. AI on the Worker: one call per group for sentences, one per answer to score.
- Shared page: no.

## Result
Per word: score 0–3. 3 = known, 0–1 = repeat, 2 = stays in queue.

## People
App only in v1.

## Acceptance criteria
- Given a word, when the sentence shows, then the English word is not visible.
- Given a translation with another right word, when scored, then the score is 2 at most and the target word is named.
- Given a translation with the target word used right, when scored, then the score is 3.
- Given the round ends, when the summary opens, then known and repeat words are listed.

## Open questions
- Which language is the sentence in: the learner's native language, set where?
- Could this move to Stage 2 (it is production)? Left in 3 because it is scored.
