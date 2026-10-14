---
status: clarified
stage: 2
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart; screenshot ai-chat-exercise-menu (Flashcards) MERGED here"
---

# Remember or not (flashcards)

**Merged:** the screenshot's "Flashcards (word → meaning → word)" is this exercise.

## Goal
Stage 2 (active). The learner sees the meaning, tries to recall the word, flips the card, then says if they remembered. Recall is the work; the rating is honest self-report.

## One round
- A round has 3 to 9 words (D-13), shuffled. Fewer than 3 shows "Not enough words for this exercise" with Back.
- Front: the meaning (D-16: stored definition, else translation; D-08 masking). Nothing else. The learner thinks or says the word aloud; the app does not listen.
- Flip button (tap on the card works too). Back: the word, the translation, one example if the word has a dialogue line (D-20 source 1; no AI call), and a speaker button.
- Two buttons under the back: "Remembered" and "Not yet". No swipe in v1.
- "Not yet" puts the card back at the end of the round, once. On its second showing the buttons are "Got it" and "Still not"; both end the card.
- The speaker plays the word in the learner's accent. It plays on tap only, never by itself.
- One pass only: meaning to word. The word-to-meaning direction is Stage 1 recognition and not part of this exercise.
- After the last card: summary, then Next round or Done.

## What it uses
- Words, translations, stored definitions; dialogue lines for the example; TTS (`PronunciationService.speak`). AI: none. Shared page: no.
- Nothing loads, so there is no error state (D-05 does not apply).

## Result
Per word: "Remembered" on 1st showing, "Remembered after repeat", or "Not yet". Summary only, with counts and the "Not yet" words listed; nothing saved (D-04). Self-rated, so a hint only, never proof.

## People
App only in v1 (D-11).

## Acceptance criteria
- Given a group of 3 or more words, when the round starts, then cards are shuffled and show only the meaning.
- Given a front, when Flip is tapped, then the word, translation and speaker button show and the two rating buttons appear.
- Given the back, when the speaker is tapped, then the word is spoken once; given the front, then no sound plays.
- Given "Not yet" on a first showing, when tapped, then the card returns once at the end; given "Still not" on its return, then it ends and does not return.
- Given a word with only a translation, when the card shows, then the translation is the front.
- Given a word that appears in its own definition, when the front shows, then the word is "___" (D-08).
- Given fewer than 3 words, when the exercise opens, then "Not enough words for this exercise" shows.
- Given the last card rated, when the round ends, then the summary shows counts and lists the "Not yet" words.

## Decisions
- Stage stays 2: the learner must produce the word before seeing it. It is self-rated, so it saves nothing and is never an exam. (agent, 2026-10-14)
- One direction only; the flashcard "word → meaning → word" idea is covered by Stage 1 matching and this card's flip. (agent, 2026-10-14)
- Two-step rating (remembered / not yet); no 1–5 scale and no spaced repetition, which need a saved result (Step 3). (agent, 2026-10-14)
- Not-yet cards return once, as in the draft, then stop: the round must end. (agent, 2026-10-14)
- Buttons only, no swipe: swipe is a new gesture and hard to test. (agent, 2026-10-14)
- TTS on tap only, so a quiet place stays quiet. (agent, 2026-10-14)
- Multi-word entries ("give up") are one card. (agent, 2026-10-14)

## Open questions
- Owner: should "Not yet" marks ever feed the Step 3 result? Default now: no, never saved.
