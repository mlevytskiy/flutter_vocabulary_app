---
status: clarified
stage: 1
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan from learn-part-step-1 §1)"
---

# Match antonyms

## Goal
Stage 1 (passive). The learner links each English word to its opposite. Opposites fix the meaning of a word by contrast.

## One round
- Same match board and round rules as Match synonyms (3 to 6 pairs, split of big groups, tap-then-tap, right pair locks, wrong pair shakes and counts one miss for the tapped word).
- The Worker's AI gives at most one antonym per word: the most common opposite for the sense of the word's translation. It is one English word (or a short phrase of up to 3 words for a phrasal word), never the word itself, never "not + word", and not another word of the round.
- Words with no true opposite (most nouns) are left out silently. Words are never given a "different from" substitute.
- If fewer than 3 words have an antonym, the screen says "Not enough words with opposites for this group" and offers Back.
- If a word and its antonym are both in the group (hot, cold), only the first in group order stays in the round; the other is left out of this round.
- If the data cannot load, one error line and Retry show; no round starts.
- The left column shows words in group order, the right column antonyms shuffled. The summary lists each word with its misses (0 as "no misses"), then Next round or Done.

## What it uses
- Words of the group and their translations (long press shows the translation of the tapped word only, never of an antonym).
- AI on the Worker: one antonym call per group, cached per word there (a separate call from synonyms; the cache is per word and kind).
- The match board of Match synonyms. Shared page: no.

## Result
Per word: misses in this round. On screen only; nothing is saved.

## People
App only in v1.

## Acceptance criteria
- Given a group of 6 words that all have opposites, when the round opens, then 6 words show in group order and 6 antonyms shuffled.
- Given 3 words in a group of 8 have no opposite, when the round is built, then those 3 are skipped and the other 5 form one round.
- Given fewer than 3 words with an opposite, when the exercise opens, then "Not enough words with opposites for this group" shows with Back and no round starts.
- Given a group with both "hot" and "cold", when the round is built, then only one of them is in the round.
- Given a wrong pair, when tapped, then nothing links, both unselect, and the tapped word gets one miss.
- Given a right pair, when tapped, then both items lock and stay linked.
- Given no network, when the exercise opens, then an error line and Retry show; Retry loads the round.
- Given all pairs linked, when the round ends, then the summary lists every word with its misses.

## Decisions
- Words without an opposite are skipped, not replaced by "different from". (agent, 2026-10-14)
- One accepted antonym per word, chosen by the AI for the translation's sense; other valid opposites count as wrong. (agent, 2026-10-14)
- Antonym form: one word (phrase up to 3 words for phrasal words), no "not + word", not the word itself. (agent, 2026-10-14)
- Mutual pairs in a group (hot/cold) keep only the first word in the round. (agent, 2026-10-14)
- Antonyms stay a separate exercise from synonyms; no merged "Match pairs" with a switch. (agent, 2026-10-14)
- Synonyms and antonyms use separate Worker calls; D-03 caching applies. (agent, 2026-10-14)

## Open questions
- Owner: antonyms exist for few words (mostly adjectives and verbs). Hide the exercise card for groups with under 3 candidates, or keep it visible with the "Not enough words" message? Default now: keep visible.
