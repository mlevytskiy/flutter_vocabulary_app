# Spec — self-check-cards (how well the learner knows a word)

Status: **tasks only, not built.** Merged with [learn-welcome](../learn-welcome/spec.md) on 2026-10-30 (owner A15): the card widget, the rating rules (AC-03 – AC-07) and `WordBox.lastCheckSide` are built there (its T2, T3, T11); this feature keeps the scheduling in exercise sessions, hints, results and the talk quick check. Owner's choices, 2026-10-27, from the decision page
https://claude.ai/artifact/N1UGqFAVpqGdio3P7z2aVK (version 2 of the word boxes,
https://claude.ai/artifact/L2NC6YLqY77WwN6zLcMX3n; D2 Leitner boxes, learn-redesign ADR-0001).

## Idea

The boxes stop moving on the app's verdict alone. A mistake or a hint only marks a word **to check**.
A few pages later a self-check card shows the word, the learner recalls it, flips the card and rates
how well they knew it: **I don't remember / Hard / Medium / Easy** (AnkiDroid style). The rating,
with one guard from what the exercises saw, moves the box once, at the end of the session.

## Owner's choices

| # | Question | Choice |
|---|----------|--------|
| 1 | When do we ask? | After a mistake; after a hint |
| 2 | How long after? | 3 pages later |
| 3 | Card front | Switch sides each time (Ukrainian → English word, then English → meaning) |
| 4 | A mistake by itself | Nothing until the card |
| 5 | Buttons → box | Anki-like: Don't remember → box 1 · Hard −1 · Medium stays · Easy +1 |
| 6 | Trust in the rating | The rating decides, with one guard: Easy right after a mistake counts as Medium |
| 7 | Cards per session | No limit |
| 8 | Talk with AI | A self-check step in the quick check |

## Acceptance criteria

- **AC-01 Flag.** A wrong page, or a right page reached only after a hint, marks the word *to check*
  with its reason (`mistake` or `hint`). It does not move the box by itself.
- **AC-02 When.** A flagged word's card comes 3 pages after the flag (pages of other words), or right
  after the last exercise page when fewer pages are left. The card is never two pages in a row with
  the same word's own page. Every flag gets a card (no limit). A word flagged again after its card
  gets a new card, and its last rating counts.
- **AC-03 Card.** The front shows one side, the back shows everything: the English word, its
  pronunciation (play), the translation and the example sentence when there is one. The four buttons
  are disabled until Flip. Under each button is the box it leads to ("→ box 1", "box 2", …).
- **AC-04 Sides.** Cards switch sides each time: Ukrainian → recall the English word, then English →
  recall the meaning, alternating per word across sessions (Q-1): the word's next card shows the
  side its last card did not.
- **AC-05 Rating → box (Anki-like).** From the box the word had before the session (new = 0):
  Don't remember → 1; Hard → max(1, box − 1); Medium → box unchanged (a new word goes to 1);
  Easy → min(5, box + 1). The next review is start of today + `intervalDays(result)` (1/2/4/8/16).
- **AC-06 Guard.** If the word's flag in this session came from a mistake, Easy counts as Medium.
- **AC-07 Once a day.** An Easy, or a clean word, moves up at most once a calendar day (the existing
  `lastUpDay` rule). Down moves always apply.
- **AC-08 Clean words.** A word with no flag moves as today: up one box, at most once a day.
- **AC-09 No rating.** A flagged word whose card was never answered (the session was left) keeps its
  box and next review.
- **AC-10 Results.** The results screen shows each word's move and, for a rated word, the rating
  that moved it.
- **AC-11 Talk.** In Talk with AI, a word missed or used only after its hint gets a self-check step
  in the quick check; its rating moves the box by AC-05–AC-07. A word flagged after the last quick
  check gets its step in a closing check of only self-check steps when the talk ends by itself (its
  last reply, or See results); the talk finishes when that check closes (owner, 2026-10-30). A talk
  word flagged but never rated (the learner ended the talk before rating it) keeps its box (AC-09).

## Owner's answers (2026-10-27)

- **Q-1 Sides.** Per word across sessions: each word's last card side is stored in a new field,
  `WordBox.lastCheckSide` (`''`, `uk` or `en`), approved by the owner (rule 5). A word's next card
  shows the other side; a word with no card yet starts on Ukrainian.
- **Q-2 The guard.** Easy counts as Medium only after a mistake; Easy after a hint stays Easy.
- **Q-3 Hints.** A right answer on the second try, after the "Starts with …" line, is a hint;
  "Show answer" is a mistake.
