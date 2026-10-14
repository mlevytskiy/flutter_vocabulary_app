---
status: clarified
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan from learn-part-step-1 §1)"
---

# Match word and definition

## Goal
Stage 1 (passive). The learner links each English word to its English definition. This builds recognition without the native language.

## One round
- Same board, round size, split rules, tap rules, error screen and summary as Match synonyms (D-01, D-02, D-05). Only the pair data differs.
- Left column: the words in group order. Right column: their definitions, shuffled.
- A card shows only the definition line (the part after "definition:"), never the example. A definition longer than about 120 characters is cut at its first sentence; if there is no sentence end, at the last whole word before 120, plus "…".
- If a definition contains its own word (whole word, any case), that word shows as "___" so it does not give the answer away.
- A word with no definition, or whose definition is the same text as another word's in the round, is left out of the round (the first in group order stays, D-07).
- If fewer than 3 usable words remain, the screen says "Not enough words with definitions for this group" and offers Back.
- Long press (or hold) on a card reads its text aloud with TTS; the translation is not shown.

## What it uses
- The row's `definition` field first (the sense the learner chose). If it is empty, the app calls the Worker's `/define` for that word and takes the first sense. Fetched text is used for this round only and is not written to the word.
- `/define` can answer "not found" or "unavailable". Not found: the word is left out. Unavailable (offline, 503) for any needed word: the error line with Retry (D-05).
- Board widget of Match synonyms. TTS. Shared page: no.

## Result
Per word: misses in this round (0 = clean). Kept on screen only; nothing saved (D-04).

## People
App only in v1.

## Acceptance criteria
- Given a group of 6 words that all have a definition, when the round opens, then 6 words show in group order and 6 definitions show shuffled, with no stored definition changed.
- Given a row with an empty definition and a dictionary answer, when the round is built, then the first sense is shown and the row's stored definition stays empty.
- Given a row with no dictionary entry, when the round is built, then it is left out and the others still show.
- Given a definition that contains its word, when the card shows, then the word reads "___".
- Given a definition of 300 characters, when the card shows, then only the first sentence (or the first 120 characters plus "…") shows.
- Given a wrong link, when tapped, then nothing links, both unselect, and the tapped word gets one miss; a right link locks both.
- Given fewer than 3 words with a definition, when the exercise opens, then the "Not enough words" message shows and no round starts.
- Given a card held with sound on, when 0.5 s passes, then its text is read aloud.

## Decisions
- The stored `definition` wins over a fetched one: it is the sense the learner picked. (agent, 2026-10-14)
- Fetched definitions are never saved; no new field (CLAUDE.md rule 5). (agent, 2026-10-14)
- A translation is never a fallback for a missing definition: it would break the English-only goal. (agent, 2026-10-14)
- Cards show the definition only, no example, no translation. (agent, 2026-10-14)
- The word inside its own definition is masked as "___". (agent, 2026-10-14)
- Long definitions are cut to the first sentence, at most about 120 characters. (agent, 2026-10-14)

## Open questions
- Owner: should "___" also hide word forms (plural, -ing, -ed)? Default now: whole word only.
