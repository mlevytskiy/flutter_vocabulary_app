---
status: cancelled
cancelled_by: H-06
blocked: "owner"
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 3 spoken variant)"
---

# Make your own sentences (speak)

**Blocked: owner.** The app has no speech-to-text (D-28). Nothing here is built until the owner picks one (Open questions). In v1 only the written own-sentences exists.

## Goal
Stage 3 (examine). It is a **"Speak" mode of own-sentences**, not a second exercise (D-35): the same round, rules and result. This file lists only what speaking adds, so the mode can be built the day speech-to-text is approved.

## What it adds over own-sentences
- Input: a mic button instead of the keyboard. The learner says one sentence.
- The transcript shows under the word, read-only.
- The same D-24 check runs on the transcript (task "own"), with the same D-26 / D-32 result: known or repeat.
- Mode choice: when speech-to-text exists, a Write / Speak switch on the exercise start. Without it, only Write shows.

## One round
- As own-sentences (3 to 5 words, exam rules D-34). The card shows only the English word.
- Tap the mic, say one sentence, tap again to stop (or it stops after 3 s of silence, at most 20 s). The transcript shows.
- The learner may **re-record once** before sending, only while nothing is checked. The new take replaces the old; a third take is not allowed. Then Send (check) or Skip.
- The app tidies the transcript (first letter capital, final full stop) before the check, so speech without punctuation is not marked wrong. Nothing else is changed; the learner cannot type into it (that would be the written mode).
- After the check, the result shows as in own-sentences. A speaker button may then read the fixed sentence (TTS, D-22).

## What it uses
- Speech-to-text (not chosen), the Worker sentence check (D-24), TTS. Shared page: no.

## Result
As own-sentences: known / repeat / not checked, summary only (D-31..D-33). The summary marks spoken words with a mic icon.

## People
App only (D-11).

## Acceptance criteria
- Given Speak mode, when a word opens, then only the English word and a mic button show (no keyboard, no hints).
- Given the learner stopped speaking, when the text is ready, then the transcript shows and cannot be edited.
- Given a transcript, when the learner re-records, then the new take replaces it once; a third take is refused.
- Given an empty or one-word transcript, when Send is tapped, then nothing is sent and "Say a full sentence" shows (it does not use up the re-record).
- Given the microphone is denied, when Speak is chosen, then a line says how to allow it and the Write mode is offered.
- Given a checked transcript, when the result shows, then the word is known or repeat as in own-sentences and cannot be retried.

## Decisions
- Merged into own-sentences as a Speak mode; this file stays only as the blocked delta. (agent, 2026-10-14)
- Score 0-3 dropped: result is known / repeat (D-31). (agent, 2026-10-14)
- Transcript is not editable: editing is typing. Fairness for mis-recognition is one re-record before the check, not after it (D-34 keeps one checked answer). (agent, 2026-10-14)
- Same D-24 contract, no "spoken" flag to the Worker; the app only adds capital and full stop. (agent, 2026-10-14)
- Speech-to-text options for the owner, none chosen: (a) on-device plugin: free, offline, audio stays on the phone, but a new package (rule 5) and weaker with accents and short words; (b) Worker transcription (AI speech model): better with accents, no package, but costs per call, needs network, and sends audio off the phone; (c) the OS keyboard's dictation: no package, but it is typing, so it cannot be told apart from the written mode and gives no mic control. (agent, 2026-10-14)

## Open questions
- Owner: which speech-to-text, (a) plugin (needs package approval), (b) Worker transcription (needs a cost and privacy OK), or none? Default now: none; Speak mode is hidden.
- Owner: is one re-record the right allowance for an exam, or none for stricter comparability? Default now: one.
