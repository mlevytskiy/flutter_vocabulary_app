---
status: draft
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 3 spoken variant)"
---

# Make your own sentences (speak)

## Goal
Stage 3 (examine). Same as Make your own sentences, but the learner says the sentence aloud. It tests the word under speaking pressure.

## One round
- The app shows the English word.
- The learner taps the mic and says one sentence.
- Speech-to-text makes a transcript, shown for a quick fix.
- The Worker's AI scores it 0–3 as in the written version.
- TTS can read the corrected sentence back.

## What it uses
- Group words, speech-to-text, TTS. AI on the Worker: one call per sentence.
- Shared page: no (needs a microphone in the app).

## Result
Per word: score 0–3, with a flag "spoken". Counts like the written score.

## People
App only.

## Acceptance criteria
- Given the mic is allowed, when the learner speaks, then a transcript shows.
- Given the mic is denied, when started, then the exercise tells how to allow it and offers the written version.
- Given a transcript, when sent, then a score 0–3 shows.
- Given the transcript is empty, when sent, then nothing is scored.

## Open questions
- Which speech-to-text: the phone's own or the Worker?
- Is this a switch inside the written exercise, not a second exercise?
