---
status: clarified
blocked: "owner"
stage: 3
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 3 spoken variant)"
---

# Translate sentences (speak)

**Blocked: owner.** The app has no speech-to-text (D-28). Nothing here is built until the owner picks one (see own-sentences-spoken, Open questions). In v1 only the written translate-sentences exists.

## Goal
Stage 3 (examine). It is a **"Speak" mode of translate-sentences**, not a second exercise (D-35): the same round, rules and result. This file lists only what speaking adds.

## What it adds over translate-sentences
- Input: a mic button instead of the keyboard. The learner reads the Ukrainian sentence and says the English translation.
- The transcript shows under the sentence, read-only. The same D-24 check runs on it (task "translate", extra = the Ukrainian sentence), with the same D-39 / D-26 / D-32 result: known or repeat.
- Mode choice: a Write / Speak switch on the exercise start, shown only when speech-to-text exists.
- Input rules are D-36: mic tap to start and stop (3 s silence, at most 20 s), one re-record before the check, app only adds capital and full stop, denied mic offers Write, an empty or one-word transcript is not sent ("Say a full sentence").

## One round
- As translate-sentences: 3 to 5 words, bold Ukrainian cue, exam rules D-34. No English word, no speaker button on the Ukrainian sentence (reading it aloud would add a hint the written mode lacks).
- After the check, the model translation shows with the word in bold, and a speaker button may read it (TTS, D-22).
- Recognition of the target word: if the transcript has a sound-alike instead of the word (e.g. "there" for "their"), the check decides; the learner's remedy is the single re-record, not an edit. A miss is repeat (D-39).

## What it uses
- Speech-to-text (not chosen), the sentence load and the check as in translate-sentences, TTS. Shared page: no.

## Result
As translate-sentences: known / repeat / not checked, summary only (D-31..D-33). Spoken words carry a mic icon in the summary.

## People
App only (D-11).

## Acceptance criteria
- Given Speak mode, when a word opens, then only the Ukrainian sentence (cue in bold) and a mic button show; no keyboard, no English word, no speaker.
- Given the learner stopped speaking, when the text is ready, then the transcript shows and cannot be edited.
- Given a transcript, when the learner re-records, then the new take replaces it once; a third take is refused.
- Given an empty or one-word transcript, when Send is tapped, then nothing is sent and "Say a full sentence" shows, without using up the re-record.
- Given the microphone is denied, when Speak is chosen, then a line says how to allow it and Write is offered.
- Given a correct spoken translation with a synonym instead of the word, when checked, then the word is repeat and the note names the word.
- Given a checked transcript, when the result shows, then the word is known or repeat as in translate-sentences and cannot be retried.

## Decisions
- Merged into translate-sentences as a Speak mode; this file stays only as the blocked delta (D-35). (agent, 2026-10-14)
- Score 0-3 and the "spoken" flag dropped: known / repeat, same check contract (D-31, D-24). (agent, 2026-10-14)
- Transcript not editable; fairness to recognition errors is one re-record before the check (D-36, D-34). (agent, 2026-10-14)
- Accent strictness: the check judges meaning and word use, not pronunciation; only the transcript is seen. (agent, 2026-10-14)

## Open questions
- Owner: which speech-to-text? Same question as own-sentences-spoken; one answer covers both. Default now: none; Speak mode hidden.
