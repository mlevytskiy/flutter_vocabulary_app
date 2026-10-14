---
status: draft
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 3 spoken variant)"
---

# Translate sentences (speak)

## Goal
Stage 3 (examine). Same as Translate sentences, but the learner says the English translation aloud.

## One round
- The app shows (and optionally reads) a Ukrainian sentence.
- The learner taps the mic and says the English translation.
- Speech-to-text makes a transcript, which the learner can fix.
- The Worker's AI scores 0–3 and shows one reason line.
- Random order, no second chance.

## What it uses
- Sentences as in Translate sentences (reuse the cache). Speech-to-text, TTS.
- AI on the Worker: one call per answer. Shared page: no.

## Result
Per word: score 0–3 with a flag "spoken".

## People
App only.

## Acceptance criteria
- Given the mic is allowed, when the learner speaks, then a transcript shows.
- Given a transcript with the target word used right, when scored, then the score is 3.
- Given the mic is denied, when started, then the written version is offered.
- Given the round ends, when the summary opens, then known and repeat words are listed.

## Open questions
- Is this a switch inside Translate sentences?
- How strict is the score for accent errors in transcripts?
