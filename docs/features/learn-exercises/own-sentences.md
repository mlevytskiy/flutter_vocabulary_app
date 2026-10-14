---
status: clarified
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart; screenshot ai-chat-exercise-menu (Speaking/writing practice) MERGED here"
---

# Make your own sentences

**Merged:** the screenshot's "writing practice - you write 5 sentences, I fix them" is this exercise.

## Goal
Stage 3 (examine). The learner writes one sentence per word with no help. The AI check gives each word a result: known or repeat (D-31, D-32). It is an exam: no hints, one try.

## One round
- A round has 3 to 5 words (D-13 split, never under 3), random order. Fewer than 3 words: "Not enough words for this exercise" with Back.
- The card shows only the English word. No translation, definition, pattern, example or speaker (exam: no hints). A text field opens with the keyboard (autocorrect off, Send submits, D-19). Prompt: "Write a sentence with <word>."
- Send runs the check (D-24, task "own"). A spinner shows. Then the result shows: "Good", or the fixed sentence and a note of at most 100 characters (word in bold, D-27). Next.
- One send per word. After a send is checked, the sentence cannot be changed and there is no second try. "Skip" ends the word as repeat.
- Summary after the last word: two lists, Known and Repeat, each word with the learner's sentence (and the fix). Then Next round or Done.

## What it uses
- Worker sentence check, one call per sentence (D-24). The Worker gets the translation so it judges the right sense; the learner does not see it.
- Group words only. No other AI call. Shared page: no.
- Check fails, times out or offline: D-25 (error line, Retry, the same sentence is sent again; it cannot be edited). Leaving the word unchecked: shown as "Not checked".

## Result
Per word, by D-26 and D-32: right = known; fixed = repeat; skipped = repeat; not checked = no result. Shown in the summary only; not saved (D-33). This differs from sentence-patterns: there the learner gets a pattern to copy and the result is practice; here nothing is given, so the result is the exam.

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a word is shown, when the card opens, then only the English word is visible: no translation, definition, pattern or speaker.
- Given an empty or one-word sentence, when Send is tapped, then nothing is sent and "Write a full sentence" shows.
- Given a correct sentence that uses the word (any form), when checked, then "Good" shows and the word is known.
- Given a sentence with an error, or without the word, when checked, then one fixed sentence and a note of at most 100 characters show, and the word is repeat.
- Given a checked sentence, when the result shows, then the field is locked and there is no way to try the word again in this round.
- Given the learner taps Skip, when the word ends, then it is repeat and no check is sent.
- Given the check fails or the phone is offline, when Send is tapped, then an error line with Retry shows and the sentence stays unchanged.
- Given the last word is done, when the round ends, then the summary lists each word under Known or Repeat.

## Decisions
- Round is 3 to 5 words, not 9: writing is slow, and the screenshot says 5. (agent, 2026-10-14)
- Exam means: nothing shown but the word, one checked send, no edit, no retry of a word. Retry after a network error is not a second try. (agent, 2026-10-14)
- The learner sees no translation; a use in another sense of an ambiguous word is judged wrong by the Worker, which has the translation. (agent, 2026-10-14)
- Typed only (D-28); the spoken version is own-sentences-spoken. No saved product of the learner (D-29). (agent, 2026-10-14)
- Sentence-patterns stays a separate, earlier Stage 2 exercise; this one gives no scaffold. (agent, 2026-10-14)

## Open questions
- Owner: save known / repeat per word? Needs a new record or a WordPair field (rule 5, D-33). Default now: summary only.
- Owner: after a round, a button "Practise repeat words" that starts a new round with only those? Default now: no.
