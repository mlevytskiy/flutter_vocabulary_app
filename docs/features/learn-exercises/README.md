---
status: draft
updated_at: "2026-10-14"
---

# Learning exercises: small specs

Stages (owner, 2026-10-14):
- **Step 1:** easiest tasks. Goal: words go into the PASSIVE vocabulary (recognise).
- **Step 2:** goal: words go into the ACTIVE vocabulary (produce).
- **Step 3:** examine the learner. Give each word a result: known well, or needs repeating.

Built already (not specced here): Mnemonic story, Dialogs from movie.
Sizes: XS very small, S, M, L. Rough guess only.

| Stage | id | Name | Source | Goal | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | [match-synonyms](match-synonyms.md) | Match synonyms | exercises.dart | Link a word to a same-meaning word | S | AI synonyms; board widget |
| 1 | [match-antonyms](match-antonyms.md) | Match antonyms | exercises.dart | Link a word to its opposite | S | match-synonyms board |
| 1 | [match-definitions](match-definitions.md) | Match word and definition | exercises.dart | Link a word to its English definition | S | match-synonyms board; define endpoint |
| 1 | [guess-my-word](guess-my-word.md) | Guess my word | Fable | Find the word from 3 clues | M | AI clues; shared-page buzzer (later) |
| 1 | [pick-the-answer](pick-the-answer.md) | Pick the right answer | exercises.dart (moved from 2) | Pick the right option of 4 | S | none |
| 2 | [fill-the-gaps](fill-the-gaps.md) | Fill the gaps | exercises.dart | Type the missing word in a sentence | M | AI sentences or dialogues |
| 2 | [remember-or-not](remember-or-not.md) | Remember or not (flashcards) | exercises.dart + screenshot | Recall the word from its meaning, then self-rate | S | TTS |
| 2 | [sentence-patterns](sentence-patterns.md) | Sentence patterns | screenshot | Reuse a pattern for your own sentence | M | AI sentences and check |
| 2 | [chain-story](chain-story.md) | Chain story | Fable | Continue a story with each word | L | mnemonic story; speech; AI check; shared-page turns |
| 3 | [own-sentences](own-sentences.md) | Make your own sentences | exercises.dart + screenshot | Write a sentence per word; scored | M | AI scoring; word result record |
| 3 | [own-sentences-spoken](own-sentences-spoken.md) | Speak mode of own-sentences (blocked: owner) | exercises.dart | Same, said aloud (D-35) | M | own-sentences; speech-to-text |
| 3 | [translate-sentences](translate-sentences.md) | Translate sentences | exercises.dart | Translate into English with the word; scored | M | AI sentences and scoring; result record |
| 3 | [translate-sentences-spoken](translate-sentences-spoken.md) | Translate sentences (speak) | exercises.dart | Same, said aloud | M | translate-sentences; speech-to-text |
| 3 | [explain-to-friend](explain-to-friend.md) | Explain it to a friend | Fable | Explain the word with no cues; scored | L | speech-to-text; AI scoring; shared-page vote (later) |
| 3 | [quiz](quiz.md) | Quiz | screenshot | 5–7 mixed questions; known or repeat | M | pick-the-answer, fill-the-gaps builders; result record |

## Merged / moved
- **Flashcards** (screenshot) merged into **remember-or-not**: same card flip, meaning to word.
- **Writing practice** (screenshot: "you write 5 sentences, I fix them") merged into **own-sentences**.
- **Examples from your world** (screenshot) is a variant of the built **Mnemonic story** (a story with a theme the learner picks). Not a new file. Proposed: add "choose a theme" to the Mnemonic story spec later.
- **Quiz** is kept as its own Stage 3 exam; it reuses the question builders of pick-the-answer and fill-the-gaps.
- **Sentence patterns** is new in Stage 2: it scaffolds production and leads to own-sentences.
- Moved: **pick-the-answer**, Stage 2 to Stage 1 (choosing is recognition; agent, 2026-10-14). `exercises.dart` must change `stage: 2` to `1` at implementation.
- Proposed move: none for fill-the-gaps (types the word: Stage 2). translate-sentences could be Stage 2 (it is production) but stays in 3 because it is scored.

## Note: the Step 3 result
Step 3 needs a per-word result (known / repeat) that is saved. Today the learn page saves nothing, and a new record needs owner approval (CLAUDE.md rule 5). One shared decision is needed before any Step 3 exercise is built.
