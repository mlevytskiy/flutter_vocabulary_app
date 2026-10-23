---
status: Reviewed
updated_at: "2026-10-23"
feature_size: "L"
tool: code
---

# Screens — learn-redesign

Drawn as markdown wireframes (design tool: code). Visual reference: the options deck
https://claude.ai/artifact/C4TCvEPHkG3taMBmehqsq7 (slides "A2, as picked", C1, results, talk).
Reuse first: existing theme, `AppDecor`, `ElevatedButton`, `showModalBottomSheet`, `PopupMenuButton`,
`SwitchListTile`, `SegmentedButton`-free radio list, `step_progress.dart` look for the step bar.

## SCR-01 Words table top bar (changed) — AC-01, AC-04, AC-27

```
[←]  [▶ Learn][👤▾]      Lisbon trip          [⇪ Share]
```
- Learn: unchanged look and place. `👤▾` = CompanionButton, an icon button (person icon + small arrow) right of Learn.
- States: default; compact/icon-only layouts as today — the companion button stays icon-only (48 px) in every layout.
- Drop-down (PopupMenuButton): `✓ Learn alone` · `With teacher — Soon` (disabled) · `With friend — Soon` (disabled).

## SCR-02 Learn sheet (new) — AC-01, AC-02, AC-03, AC-05, AC-06, AC-14, AC-20

```
 ───── (handle)
 How do you want to learn?            [⚙]
 34 words · 5 due
 ┌───────────────────────────────┐
 │ Exercises                     │
 │ 3 steps · a mix of short tasks│
 └───────────────────────────────┘
 ┌───────────────────────────────┐
 │ Talk with AI                  │
 │ Talk using your words         │
 └───────────────────────────────┘
 [☑] Split words into groups of 7–12      (only with ≥ 20 words)
     Next: Food and drink · 9 words
```
- States: default (< 20 words: no checkbox, no "Next" line); grouping in progress ("Grouping your words…" under the checkbox, Exercises still enabled — waits for groups); grouping failed ("Could not group your words" + Try again; while split is ticked and there are no groups, Exercises and Talk with AI are disabled — unticking split enables them on all words); no words to learn → sheet not opened, SnackBar "Add words with a translation to start learning" (AC-03).

## SCR-03 Learning session (new) — AC-08, AC-09, AC-10, AC-11, AC-16

```
 ✕  [■■■■■][■■□□□][□□□□□]   14 / 32
 Fill the gap
 ┌───────────────────────────────┐
 │ We decided to ___ through the │
 │ old streets until sunset.     │
 └───────────────────────────────┘
   (answer slot: page body — choices / typed field / board)
 [            Check            ]
```
After Check, verdict bar slides up from the bottom:
```
 ✓ Right                         (or ✗ Not quite — the right answer)
 wander — блукати
 [          Continue           ]
```
- States: loading (spinner + "Preparing your session…"); error (one line "Could not load the exercises" + Retry; pages without AI data still play); page; verdict right / wrong; leave confirm dialog "Leave the session? Progress in this session is lost." [Stay] [Leave]; empty (fewer than 3 usable words for every drawn type → falls back to Remember or not / Pick the right answer pages; if still none: "Not enough words to learn yet" + Back).
- Board pages (match synonyms/definitions): the board fills the card; Check is replaced by the board's own completion; verdict shows "3 of 4 right".
- Remember or not: buttons "I knew it" / "I didn't" replace Check.

## SCR-04 Session results (new) — AC-07, AC-12, AC-22

```
 Session done
 32 pages
 [ 7 know well ][ 3 shaky ][ 2 new ]
 wander ............. in 4 days
 harbour ............ in 2 days
 crowded ............ tomorrow
 (talk only) 4 words not used — unchanged
 [ Practise 3 shaky words ]   (when any shaky)
 [ Next group ]               (when split is on)
 [ Done ]
```
- States: default; nothing written (collection was binned meanwhile: same screen, a line "This collection is in the recycle bin — results not saved").

## SCR-05 Learn settings (new) — AC-17, AC-18, AC-19

```
 ← Learn settings
 Preset
 (•) Balanced — about 10 min
 ( ) Quick — about 5 min, one-word answers only
 ( ) Deep — about 20 min, all exercises
 ( ) Custom
 Words per session   [All ▾]     (10 / 20 / 30 / All)
 Step 1 · Meet
   Mnemonic story ................ [Try it]
   Dialogs from movie ............ [Try it]
   Match synonyms ........ [Try it] [⬤]
   …
 Step 2 · Practise …
 Step 3 · Use …
```
- States: default; refusing the last switch of a step → SnackBar "Each step needs at least one exercise".

## SCR-06 Talk with AI (new) — AC-20, AC-21, AC-24, AC-25, AC-26

```
 ←  Talk with AI                     2 / 12
 [AI] You're in Lisbon. Where did you go first?
                 [me] I wandered around the harbour.
 [AI] Nice! Was it busy there?
 ─────────────────────────────────
 wander ✓  harbour ✓  crowded  rush  sunset
 [Hint]  [ type a reply…        ] [Send]  [🎤 hold]
 [ End talk ]
```
- States: starting (spinner "Setting the scene…"); talking; waiting for AI (typing dots); hint available (Hint enabled after 2 replies without the target word; tap shows "Try using: crowded"); day limit ("Today's talk limit is reached. Try again tomorrow." + Back); error (one line + Retry, typed text kept); listening (mic button filled, "Listening…"); permission refused ("Allow the microphone and speech recognition in Settings to talk" + typing stays); ended (auto after 12 replies or all words used → results SCR-04).
- The mic button shows only when speech input is available (voice milestone).
