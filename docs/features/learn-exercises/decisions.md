---
status: living
updated_at: "2026-10-14"
---

# Shared decisions — learning exercises

Decisions that affect more than one exercise. Every improvement pass reads this file first and
appends what it decided. Agent decisions are marked **(agent, date)**; the owner may revise any.
Format: `D-NN — question → decision. Why. Affects: ids.`

## Open (cross-cutting)
- Step 3 needs a saved per-word result (known / repeat). The learn page saves nothing today; a new
  record needs owner approval (CLAUDE.md rule 5).
- `docs/lightning_icon_rules.md` covers only the AI-translate buttons; it does not map scores to
  known / repeat.

## Decided

D-01 — Which board widget do the match exercises share? → One "match board": two columns, tap-then-tap, right pair locks, wrong pair shakes and unselects, per-word miss count, summary at the end. match-synonyms builds it; antonyms and definitions reuse it with different pair data. Why: same interaction, avoids three copies. Affects: match-synonyms, match-antonyms, match-definitions. (agent, 2026-10-14)
D-02 — How many words per round in match exercises? → 3 to 6 pairs; larger groups split into rounds, never a round under 3; fewer than 3 usable words shows a "not enough words" screen. Why: fits one phone screen and keeps the round meaningful. Affects: match-synonyms, match-antonyms, match-definitions. (agent, 2026-10-14)
D-03 — Where is AI exercise data (synonyms, antonyms, definitions, clues) generated and cached? → On the Worker: one call per group, cached per word there. The app keeps nothing new on disk and adds no field to WordPair (CLAUDE.md rule 5). Why: no new model; repeat opens are free. Affects: match-synonyms, match-antonyms, match-definitions, guess-my-word, fill-the-gaps. (agent, 2026-10-14)
D-04 — What does a Stage 1 exercise record? → Per-word misses for the round, shown in the end summary only; nothing saved. Step 3 owns saved results. Why: matches the open Step 3 decision. Affects: all Stage 1 and 2 exercises. (agent, 2026-10-14)
D-05 — What happens when exercise data cannot load? → An error line with Retry; no partial round. Why: one predictable behaviour. Affects: all exercises using AI data. (agent, 2026-10-14)
D-06 — Which sense does the AI use for a word? → The Worker gets the word and its translation and answers for that sense; it may return "none" for a word. Why: "light" or "bank" would otherwise give wrong answers. Affects: match-synonyms, match-antonyms, match-definitions, guess-my-word, fill-the-gaps. (agent, 2026-10-14)
D-07 — Can an answer equal another word of the same match round? → No. The AI is told to avoid it; if it happens anyway, only the first word in group order stays in the round and the other is left out of it. Why: two valid answers make a fair miss impossible. Affects: match-synonyms, match-antonyms, match-definitions. (agent, 2026-10-14)
D-08 — Does an exercise that shows a definition or clue reveal its own word? → No. The word, as a whole word in any case, shows as "___" inside any definition, clue or example sentence on a card. Why: otherwise the answer is given away. Affects: match-definitions, guess-my-word, fill-the-gaps. (agent, 2026-10-14)
D-09 — Where does an exercise take a word's definition from? → The row's stored `definition` first (the learner's chosen sense). If empty, the Worker `/define` (dictionary, first sense), used for the round only and never written to the word. A translation is never a stand-in. Why: keeps the chosen sense, adds no field. Affects: match-definitions, guess-my-word, fill-the-gaps. (agent, 2026-10-14)
D-10 — How long may text on a match card be? → About 120 characters; longer text is cut at its first sentence, else at a whole word plus "…". Why: cards must fit a phone column. Affects: match-synonyms, match-antonyms, match-definitions. (agent, 2026-10-14)
D-11 — Is any "People" feature on the shared page (buzzer, votes, turns, people-written text) in v1? → No. The shared page is a published snapshot with no live state or write-back. All exercises are app-only in v1; People sections describe later steps and need their own spec first. Why: no live multi-user state exists today. Affects: guess-my-word, chain-story, explain-to-friend, match-synonyms. (agent, 2026-10-14)
D-12 — How is a round scored when it has a score per word? → Score per word is kept on screen in the end summary only (0 = not found). Wrong guesses after the last clue end that word with 0 and show the answer; no endless guessing. Why: ends every round and fits D-04. Affects: guess-my-word, pick-the-answer, quiz. (agent, 2026-10-14)
D-13 — How big is a round for grid-style exercises? → 3 to 9 words when the learner picks from a grid (same even-split rule as D-02, no round under 3). Why: a grid wraps on a phone; match boards stay 3 to 6. Affects: guess-my-word, pick-the-answer. (agent, 2026-10-14)
