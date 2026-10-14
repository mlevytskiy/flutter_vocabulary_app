---
status: draft
stage: 2
updated_at: "2026-10-14"
source: "screenshot ai-chat-sentence-patterns (sentences with a Pattern line)"
---

# Sentence patterns

## Goal
Stage 2 (active). The learner sees each word in a good sentence with a reusable pattern, then makes their own sentence with the same pattern. The pattern is the scaffold for producing.

## One round
- The Worker's AI writes one natural sentence per word, with the word in bold.
- Under it, a "Pattern:" line, for example "The main + [noun] + was that + [sentence]", and when to use it.
- The learner reads it and taps TTS.
- Then the learner fills the pattern with their own sentence, for the same word.
- The AI gives one short fix line. The learner goes to the next word.

## What it uses
- Group words. AI on the Worker: one call per group for sentences and patterns (cached); one call per learner sentence to check.
- TTS. Shared page: the sentence and pattern view can be shown (read only).

## Result
Per word: the learner's sentence used the word and the pattern right, or needed a fix.

## People
App only in v1. The read-only list of sentences may appear on the shared page later.

## Acceptance criteria
- Given a group, when the round starts, then each word has a sentence and a pattern line.
- Given a pattern, when shown, then the word is bold and slots are marked with [noun], [verb].
- Given the learner's sentence, when checked, then one fix line shows.
- Given an empty sentence, when sent, then it is not accepted.

## Open questions
- Is this a separate exercise or the first half of Make your own sentences?
- Show patterns only (no writing) as a Stage 1 reading mode?
