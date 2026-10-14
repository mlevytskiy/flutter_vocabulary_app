---
status: clarified
stage: 2
updated_at: "2026-10-14"
source: "Fable ideas (fable-ideas.md §2)"
---

# Chain story

## Goal
Stage 2 (active). The learner uses each word in their own English sentence that continues the group's built Mnemonic story. The story gives the plot; the sentence is the learner's.

## One round
- Needs the group's Mnemonic story. A group with no story shows "Make the story for this group first" with Back. The exercise never makes a story.
- The chain opens with the story's first sentence, shown as written (Ukrainian with its English word inside; sentences are split at "→"). It is the only non-English line. Its word counts as used.
- Words: the group's other words in group order, 3 to 9 (D-13). Fewer than 3 left shows "Not enough words for this exercise" with Back.
- Card: the chain so far, then the next word with its translation, and a text field (keyboard open, autocorrect off, Send submits, D-19). Prompt: "Continue the story with <word>."
- Send runs the check (D-24, task "story", extra = the last 8 lines of the chain). One send per word (D-26). "Skip" ends the word as skipped.
- Then one line shows: "Good" or the fixed sentence with a note (at most 100 characters). The line added to the chain is the learner's sentence if `ok`, else `fixed`. A skipped word adds no line.
- After the last word the whole chain shows with the speaker button; TTS reads the English lines only (D-22), on tap.

## What it uses
- Group words, the group's stored story (no new field). One check call per sentence (D-24, D-25). No other AI.
- Typing only: the app has no speech-to-text (D-28). TTS for the end. Shared page: no.

## Result
Per word: right, fixed or skipped (D-26). Summary lists them under the chain. Nothing saved (D-04); the chain is not kept.

## People
App only in v1 (D-11). Turns and authors on the shared page need their own spec later.

## Acceptance criteria
- Given a group with a story and 3 or more other words, when the exercise starts, then the story's first sentence and the first word show.
- Given a group with no story, when the exercise is opened, then "Make the story for this group first" shows and nothing is checked.
- Given an empty or one-word sentence, when Send is tapped, then nothing is sent and "Write a full sentence" shows.
- Given a sentence that uses the word and fits the story with no error, when checked, then "Good" shows, the word is right and the sentence joins the chain.
- Given a sentence with an error, without the word, or off the story, when checked, then one fixed sentence and a note show, the word is fixed, the fixed sentence joins the chain, and no second try is offered.
- Given the check fails or the phone is offline, when Send is tapped, then an error line with Retry shows and the typed text stays.
- Given the last word is done, when the chain shows, then every line is listed in order and the speaker button reads the English lines.
- Given a skipped word, when the chain shows, then it has no line and the word is skipped in the summary.

## Decisions
- The story is the built Mnemonic story, never a fresh AI plot; one source, no extra cost. (agent, 2026-10-14)
- The opening line stays in Ukrainian as built; no translation call. The learner's lines are English. (agent, 2026-10-14)
- Typed input only in v1 (D-28). (agent, 2026-10-14)
- "Our version" is not saved in v1: no new record (CLAUDE.md rule 5) and D-04. (agent, 2026-10-14)
- Off-topic or word missing is judged by the same check (`usesTask` false, `usesWord` false), so the sentence is "fixed", not rejected; this refines the old "asked again" wording and follows D-26. (agent, 2026-10-14)
- The check sees only the last 8 chain lines to keep the call small. (agent, 2026-10-14)

## Open questions
- Owner: save the finished chain as the group's "our version"? Needs a new record or a StoryRun kind. Default now: not saved.
- Owner: add speech-to-text (a new package) for the "dictate" idea? Default now: typing only.
