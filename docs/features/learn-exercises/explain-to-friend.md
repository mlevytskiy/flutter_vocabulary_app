---
status: clarified
stage: 3
updated_at: "2026-10-14"
source: "Fable ideas (fable-ideas.md §3)"
---

# Explain it to a friend

## Goal
Stage 3 (examine). The learner explains each word in English with no cues and without saying the word. The result per word is known or repeat (D-31, D-32). It is an exam (D-34).

## One round
- A round has 3 to 5 words (as own-sentences), random order. Fewer than 3 words: "Not enough words for this exercise" with Back.
- Start screen: two modes, "Type" (default) and "With a friend". The mode is fixed for the round.
- **Type.** The card shows only the English word and a countdown of 90 s that starts when the card opens (keyboard open, autocorrect off, D-19). Prompt: "Explain <word> in English. Do not use the word or a translation." Send runs the check. When the countdown ends, the text typed so far is sent as it is; empty text ends the word as repeat without a check.
- **With a friend.** The learner reads the word, then explains it aloud to someone next to them; a 30 s countdown shows. When it ends (or the learner taps Done), the friend taps "Understood" or "Not yet". No AI, no recording.
- A result shows at once: Good, or a note of at most 100 characters (D-24). "Skip" ends the word as repeat. No edit and no retry of a word.
- Summary after the last word: Known and Repeat lists, each word with the learner's explanation (Type mode).

## What it uses
- Type: Worker check, one call per explanation (D-24, task "explain", extra empty). The Worker gets the translation so it judges the right sense; the learner does not see it. Error, timeout or offline: D-25 (the same text is resent, a retry is not a second try).
- With a friend: nothing from the Worker. Shared page: no.

## Result
Type: `ok` = known; not `ok` = repeat; skipped or empty at time-out = repeat; never checked = no result. With a friend: Understood = known; Not yet = repeat. Shown in the summary only, not saved (D-33). The explanation is not saved either (D-29).

## People
App only in v1 (D-11). The friend in "With a friend" is a person holding the same phone; there is no shared-page vote, no recording and no human override of the AI.

## Acceptance criteria
- Given a word is shown, when the card opens, then only the English word and the countdown are visible: no translation, definition, example or speaker, and in Type mode the countdown starts.
- Given the 90 s end, when text was typed, then that text is sent for the check; when the field is empty, then the word is repeat and nothing is sent.
- Given an explanation in English that gives the meaning without the word, when checked, then "Good" shows and the word is known.
- Given an explanation that contains the word (any form), a translation or Ukrainian text, or a wrong meaning, when checked, then a note of at most 100 characters shows and the word is repeat.
- Given a checked explanation, when the result shows, then the field is locked and the word cannot be tried again.
- Given the check fails or the phone is offline, when Send is tapped, then an error line with Retry shows and the text stays unchanged.
- Given "With a friend", when the countdown ends, then "Understood" and "Not yet" show, and the tap sets known or repeat with no network call.
- Given the last word is done, when the round ends, then the summary lists each word under Known or Repeat.

## Decisions
- Kept as its own exercise: own-sentences asks for the word in a sentence; this one forbids the word and tests the meaning. (agent, 2026-10-14)
- Typed only (D-28). The 30 s timer was for speaking; typing gets 90 s, speech 30 s. Timer rule: D-40. (agent, 2026-10-14)
- The check is the "explain" task (D-40): unlike own-sentences, grammar is not judged, only meaning, no word, no translation. (agent, 2026-10-14)
- Score 0-3 is replaced by known / repeat (D-31); "stays in queue" is dropped. (agent, 2026-10-14)
- "With a friend" is in v1: it needs no shared page, no speech-to-text and no AI. Time is not the score. The learner could tap for themselves; accepted, it is an in-person mode. (agent, 2026-10-14)
- The Speak mode of the AI check follows D-35 and D-36 and is blocked until the owner approves speech-to-text; no separate file. (agent, 2026-10-14)

## Open questions
- Owner: a shared-page vote and a recording for table-mates (D-11) in a later step? Default now: no.
- Owner: save known / repeat per word (rule 5, D-33)? Default now: summary only.
