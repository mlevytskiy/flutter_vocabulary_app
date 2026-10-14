---
status: draft
stage: 3
updated_at: "2026-10-14"
source: "Fable ideas (fable-ideas.md §3)"
---

# Explain it to a friend

## Goal
Stage 3 (examine). The learner explains each word with no cues. How well they do decides "known" or "repeat".

## One round
- The app shows a word (English only) and a 30-second timer.
- The learner records an explanation: a definition, an example, a synonym. No translation.
- Speech-to-text makes a transcript.
- The Worker's AI scores it 0–3 with one line of reason.
- The whole group, random order, no second chance.

## What it uses
- Group words, speech-to-text. AI on the Worker: one call per word.
- Shared page: see People.

## Result
Per word: score 0–3. 3 = known, 0–1 = repeat, 2 = stays in queue.

## People
Table-mates on the shared link are the friend. They read the transcript and tap "I got it" or "I did not" before the AI score shows; a human "did not" lowers an AI 3 to 2. In-person mode: a table-mate taps, time is the score, no AI.

## Acceptance criteria
- Given a word, when shown, then no translation is visible and the timer starts on record.
- Given 30 seconds pass, when it ends, then the recording stops and is sent.
- Given a transcript, when scored, then a score 0–3 and a reason line show.
- Given a human vote "did not", when the AI gave 3, then the final score is 2.
- Given the round ends, when the summary opens, then known and repeat words are listed.

## Open questions
- Needs shared-page audio or transcript playback; is it in v1?
- Note: "lightning-icon rules" in the Fable text are about AI-translate buttons, not known/repeat. Which store holds the score?
