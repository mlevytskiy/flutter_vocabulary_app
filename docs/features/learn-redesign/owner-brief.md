# learn-redesign — owner brief (2026-10-23)

The owner chose from the options deck https://claude.ai/artifact/C4TCvEPHkG3taMBmehqsq7 and
asked that a Fable 5.1 agent answer the SDD questions in their place ("owner via Fable 5.1 proxy").

## The owner's own words

> 1) move all this type of exercises in settings (screen where you can pick types of exercises)
> 2) when we click learn we start learning instead of picking exercises — and we have only 2 options
>    to pick before learn: learn in speaking mode with AI and learn with exercises
> 3) near the button 'learn' on the right side I want a button with preselected options — learn alone,
>    learn with teacher, learn with friend
> 4) for now we implement only learn alone
> 5) when we pick learn with exercises we start learning with a predefined mix of exercises. 3 steps
>    (each step has several exercises picked randomly). Each exercise has exercise pages (part of the
>    exercise — just one word, or one page of sentences with gaps) and when we learn we mix these pages
> 6) we should understand how well we know words at the end (and a system like AnkiDroid that helps
>    repeat words after some time)
> 7) improve design of our exercises
> 8) plan how to implement voice conversation with AI for learning words

Picks: "A2 (add a checkbox in this dialog — split words into smaller groups (7–12 words in a group);
if we have less than 20 words we shouldn't show the checkbox and shouldn't split words). Also the
possibility to pick (learn alone, with teacher, with friend) shown near the learn button (just
drop-down options). B2+B3, C1, D2, E2, V3."

Then: "learn button should be the same as we have now; just add an extra button near it (alone, with
teacher, with friend). Everything else I approved. Use the sdd plugin and a Fable 5.1 subagent instead
of me to create tasks. After that implement these tasks."

## What the picks mean

- **Learn button**: unchanged look and place (the words-table top bar, `LearnShareBar`). Beside it a new
  small button opens a drop-down: Learn alone (selected), With teacher, With friend (both "Soon",
  disabled). Only "alone" works.
- **A2 sheet**: tapping Learn opens a bottom sheet with two cards — Exercises and Talk with AI — and,
  only when the collection has 20+ words, a checkbox "Split words into groups of 7–12". Under 20
  words: no checkbox, no split, the session takes all words.
- **B2+B3**: a session plays exercise *pages* (one word / one gap sentence / one 4-pair board) in
  word-ladder order: each word climbs Meet (step 1) → Practise (step 2) → Use (step 3); a miss sends it
  one rung down and back into the queue a few pages later. With split on, a session is one group of
  7–12 words. Each step draws 2–3 random exercise types from the enabled ones.
- **C1 page look**: one frame for all pages — a card, answers under it, Check, then a verdict bar
  (right/wrong, word — translation, Continue); a 3-segment progress bar (Meet/Practise/Use) and a
  page counter at the top.
- **D2 Leitner**: 5 boxes per word; reviews after 1, 2, 4, 8, 16 days. A word that finishes its ladder
  with no miss moves up one box; any miss sends it to box 1. New words are "new" (no box). A results
  screen at the end shows know well / shaky / new, each word's next review, "Practise N shaky words",
  "Done"; the Learn sheet shows the due count.
- **E2 settings**: Learn settings screen with presets Quick (~5 min, no typing), Balanced (~10 min),
  Deep (~20 min, writing) and Custom (the 13 exercises grouped by step with switches; each step needs
  at least one on). Words per session. Each exercise row may offer "Try it" to open it alone as today.
- **V3 voice**: Talk with AI — the AI sets a scene from the collection, asks questions whose answer
  needs a target word, the app (not the AI) ticks words the learner used (same word check as the
  exercises), hints after two misses, a summary at the end feeds the Leitner boxes. Built text-first
  (typing), then voice: speech-to-text on the phone, Claude replies in text via the Worker, flutter_tts
  speaks it.

## Assumptions the owner approved ("everything else I approved")

1. With split on, one session = one group; the results screen offers "Next group".
2. The split checkbox is remembered per collection and starts on.
3. A session takes due words first, then new words, up to the group size.
4. The box moves once per word per session: up after a clean ladder, to box 1 after any miss.
5. Groups come from the existing AI word grouping, tightened to 7–12 words per group.
6. Approvals: the new screens and visible changes (CLAUDE.md rule 3); a per-word Leitner record, a new
   domain model (rule 5); speech-to-text for V3 — a package or native code (rule 5); a Worker
   endpoint and daily allowance for talk.

Not in scope now: With teacher, With friend (only shown as "Soon"); real-time voice (V2).
