---
status: clarified
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan from learn-part-step-1 §1)"
---

# Match synonyms

## Goal
Stage 1 (passive). The learner links each English word to an English word with the same meaning. This builds recognition of the word and its neighbours.

## One round
- A round has 3 to 6 pairs. A group of more than 6 usable words is split into rounds of 6; if the last would have 1–2 words, the last two rounds share the words evenly (never a round under 3).
- The Worker's AI gives one simple synonym per word: one English word, not the word itself, not shared with another word of the round.
- The screen shows two columns: the words in group order, the synonyms shuffled.
- The learner taps a word, then a synonym (either order works). A right pair locks and stays linked. A wrong pair shakes, unselects both, and counts one miss for the tapped word.
- A word with no good synonym is left out. If fewer than 3 usable words remain, the screen says "Not enough words with synonyms for this group" and offers Back.
- When the data cannot be loaded (offline, Worker error), the screen shows one error line and a Retry button; no round starts.
- The round ends when all pairs are linked. A summary lists each word with its misses (0 shown as "no misses"), then Next round or Done.

## What it uses
- Words of the group; the word's translation as a hint on long press (shows the translation of the tapped word, never of a synonym).
- AI on the Worker: one call per group returns synonyms for all its words. The Worker caches per word, so a repeat open costs nothing.
- Shared page: no.

## Result
Per word: number of misses in this round (0 = clean). Kept on screen only; nothing is saved (Step 3 owns "known / repeat").

## People
App only in v1. Later: a table-mate can race on the shared page.

## Acceptance criteria
- Given a group of 6 usable words, when the round opens, then 6 words show in group order and 6 synonyms show shuffled.
- Given a right pair, when tapped, then both items lock and stay linked.
- Given a wrong pair, when tapped, then nothing is linked, both unselect, and the tapped word gets one miss.
- Given a word with no synonym, when the round is built, then it is skipped and the others still show.
- Given a group where fewer than 3 words have synonyms, when the exercise opens, then the "Not enough words" message shows and no round starts.
- Given no network, when the exercise opens, then an error line and Retry show; Retry loads the round.
- Given a group of 8 usable words, when rounds are built, then the rounds are 4 + 4, never a round under 3.
- Given all pairs linked, when the round ends, then the summary lists every word with its misses.

## Decisions
- Beginners get no synonym translation; the long-press hint covers the word only. (agent, 2026-10-14)
- Round size is up to 6, not the whole group; minimum 3. (agent, 2026-10-14)
- Synonym rules: one English word, unique in the round, not equal to the word. (agent, 2026-10-14)
- Wrong tap counts a miss on the tapped word; repeated wrong taps each count. (agent, 2026-10-14)
- Empty and error states are explicit screens, not a broken round. (agent, 2026-10-14)
- Synonyms come from the Worker, cached there per word; the app adds no new model or saved field. (agent, 2026-10-14)

## Open questions
- Owner: should a synonym that is itself another word in the group be allowed (it makes two valid answers)? Default now: not allowed; the AI is told to avoid it.
