---
status: clarified
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 3)"
---

# Translate sentences

## Goal
Stage 3 (examine). The learner translates a Ukrainian sentence into English, using the target word for the marked part. The result shows which words can be produced from meaning alone: known or repeat (D-31, D-32). It is an exam (D-34).

## One round
- A round has 3 to 5 words (D-13 split, never under 3), random order. Fewer than 3 words with a sentence: "Not enough words for this exercise" with Back.
- The card shows only a Ukrainian sentence. The part that stands for the word (its stored translation) is in bold. No English word, definition, example or speaker. A text field opens with the keyboard (autocorrect off, Send submits, D-19). Prompt: "Translate into English."
- Send runs the check (D-24, task "translate", extra = the Ukrainian sentence). Then the result shows: "Good", or the fixed sentence and a note of at most 100 characters; always the model translation, with the word in bold (D-27).
- One send per word, no edit after the check, no second try. "Skip" ends the word as repeat and shows the model translation.
- Summary after the last word: Known and Repeat lists, each word with the learner's translation. Then Next round or Done. Spoken variant: a Speak mode of this exercise (D-35), blocked by D-28.

## What it uses
- Worker, one call per group: for each word a simple Ukrainian sentence and a model English translation holding the word once. The Worker gets word and translation (D-06) and writes the Ukrainian sentence so the word's sense is clear; it must not contain the English word. The app drops any word whose sentence has the English word in it (D-08), and any word the Worker returns "none" for.
- Worker sentence check, one call per answer (D-24). Group words only. Shared page: no.
- Load or check fails, times out, offline: D-05 / D-25 (error line, Retry, same answer resent). Unchecked word: "Not checked", no result.

## Result
Per word, by D-26 and D-32: right = known; fixed = repeat; skipped = repeat; not checked = no result. Summary only (D-33). The English word is judged by the check: a good translation that uses another word for the bold part is not `ok` (D-39).

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a word is shown, when the card opens, then only the Ukrainian sentence is visible, with the translation part in bold, and no English word of the group.
- Given an empty or one-word answer, when Send is tapped, then nothing is sent and "Write a full sentence" shows.
- Given a correct translation that uses the word (any form), when checked, then "Good" shows with the model translation, and the word is known.
- Given a correct translation that uses a synonym instead of the word, when checked, then the word is repeat, the note names the word, and the fixed sentence uses it.
- Given a translation with an error, when checked, then one fixed sentence and a note of at most 100 characters show, and the word is repeat.
- Given a checked answer, when the result shows, then the field is locked and the word cannot be tried again in this round.
- Given the learner taps Skip, when the word ends, then it is repeat, no check is sent and the model translation shows.
- Given the last word is done, when the round ends, then the summary lists each word under Known or Repeat.

## Decisions
- Direction is Ukrainian to English, fixed. The sentence language is the language of the stored translations (Ukrainian for this app). (agent, 2026-10-14)
- The bold Ukrainian part tells which English word is meant; without it a synonym would be an unfair miss. The English word and the model translation stay hidden until the result. (agent, 2026-10-14)
- Dialogue lines (D-20) are English, so they are not used here; sentences come from the Worker, one call per group (D-03). (agent, 2026-10-14)
- Round is 3 to 5 words, as own-sentences: typing a full sentence is slow. (agent, 2026-10-14)
- Stays in Stage 3: it is scored as an exam. The old 0-3 score is replaced by known / repeat (D-31). (agent, 2026-10-14)

## Open questions
- Owner: is a synonym that is fully correct English still "repeat"? Default now: yes, the exam is about this word.
- Owner: save known / repeat per word (D-33)? Default now: summary only.
