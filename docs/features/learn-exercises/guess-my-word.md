---
status: draft
stage: 1
updated_at: "2026-10-14"
source: "Fable ideas (fable-ideas.md §1)"
---

# Guess my word

## Goal
Stage 1 (passive). The learner finds the word from a short English description. Each clue is a new way to meet the word.

## One round
- The Worker's AI writes 3 clues per word (vague, closer, almost a giveaway; never the word).
- The screen shows clue 1 and a grid of the group's words.
- The learner taps a word. Right on clue 1 scores 3, on clue 2 scores 2, on clue 3 scores 1.
- A wrong tap greys the word out and shows the next clue.
- The round ends when every word is found. A summary shows which words needed all 3 clues.

## What it uses
- Group words, translations (hint on long press).
- AI on the Worker: one call per group, clues cached with the group.
- Shared page: see People.

## Result
Per word: clues used (1–3, or "not found"). Words that always need clue 3 are suggested for Step 3 review.

## People
Up to 3 people on the shared link see clue 1 and race to shout the word; the learner taps the first one. A person may also write their own clue (needs a write-back on the shared page).

## Acceptance criteria
- Given a group, when the round opens, then clue 1 and the word grid show.
- Given a wrong tap, when it happens, then that word greys out and the next clue shows.
- Given a clue contains the target word, when clues are made, then it is rejected and asked again.
- Given all words are found, when the round ends, then the summary shows clues used per word.
- Given 9 or more words, when the grid is built, then the group is split to at most 9 words per round.

## Open questions
- Is the shared-page buzzer part of v1 or v2?
- Do human clues replace the AI clues or sit beside them?
