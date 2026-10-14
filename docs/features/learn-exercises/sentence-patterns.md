---
status: clarified
stage: 2
updated_at: "2026-10-14"
source: "screenshot ai-chat-sentence-patterns (sentences with a Pattern line)"
---

# Sentence patterns

## Goal
Stage 2 (active). The learner sees each word in a good sentence with a reusable pattern, then writes their own sentence with the same word and pattern. The pattern is the scaffold for producing.

## One round
- A round has 3 to 9 words (D-13), group order. A word the AI returns "none" for (D-06) is left out; fewer than 3 left shows "Not enough words for this exercise" with Back.
- Show card: the sentence with the word in bold (the app bolds the whole-word match; the AI sends plain text), a line "Pattern: The main + [noun] + was that + [sentence]", and a line "Use it to: ..." (when to use it). A speaker button reads the sentence (D-22). The translation of the word shows small under the card.
- Button "My turn". The card stays on top; below it a text field opens with the keyboard (autocorrect off, Send submits, D-19). The prompt: "Write your own sentence with <word> and this pattern."
- Send runs the check (contract D-24). A spinner shows while it works. Then one line shows: "Good" or the fixed sentence plus a note of at most 100 characters. Next.
- One send per word; no second try. "Skip" ends the word as skipped.
- Summary after the last word: each word as right, fixed or skipped, then Next round or Done.

## What it uses
- Worker call 1, once per group, cached per word there (D-03, D-06): for each word `{sentence, pattern, usage}`. Sentence: one natural sentence of at most 15 words, the word exactly once. Pattern: at most 60 characters, the target word replaced by a slot; slots only [noun], [verb], [adjective], [sentence], [verb in Past Simple]. Usage: at most 60 characters. A dialogue line is not used (it has no pattern).
- Worker call 2, one per learner sentence: the sentence check (D-24). Not cached.
- Word, translation, TTS. Shared page: no.
- Load or check fails, or offline: D-05 (error line, Retry). The typed sentence is kept.

## Result
Per word: right (word and pattern used, no error), fixed (anything else, fix shown), skipped (0). Summary only; nothing saved (D-04, D-12). A failed check that is never retried counts as skipped.

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a group of 3 or more words, when the round starts, then each shown word has a sentence, a pattern line and a usage line, and the word is bold in the sentence.
- Given a pattern, when shown, then its slots are written in square brackets and the target word is not spelled out in the pattern.
- Given an empty or one-word sentence, when Send is tapped, then nothing is sent and "Write a full sentence" shows.
- Given a sentence that uses the word and the pattern with no error, when checked, then "Good" shows and the word is right.
- Given a sentence with a mistake or without the pattern, when checked, then one fixed sentence and a note of at most 100 characters show, and the word is fixed.
- Given the word in another form ("walked" for "walk"), when checked, then it is accepted as using the word.
- Given the check fails or the phone is offline, when Send is tapped, then an error line with Retry shows and the typed sentence stays.
- Given the last word is done, when the round ends, then the summary lists each word as right, fixed or skipped.

## Decisions
- Separate exercise in Stage 2, before own-sentences (Stage 3, scored); it gives the learner a frame, own-sentences gives none. (agent, 2026-10-14)
- AI writes sentence, pattern and usage in one call per group; plain text, the app does the bolding. No dialogue lines. (agent, 2026-10-14)
- "Used the pattern" means: the fixed words of the pattern appear in the same order; slots may hold any fitting words; tense follows the pattern's hint. The AI judges, not the app. (agent, 2026-10-14)
- Inflected forms of the word are fine here (D-18 is for typed single words, not sentences). (agent, 2026-10-14)
- Check text is limited to 200 characters; the app checks only for empty, fewer than 2 words, and length before sending. (agent, 2026-10-14)
- A pattern-only reading mode is not built; the show card is that reading step. (agent, 2026-10-14)

## Open questions
- Owner: merge this into own-sentences as its first half? Default now: separate exercise.
- Owner: should "fixed" score less than "right" in a later saved result? Default now: summary labels only.
