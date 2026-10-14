---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-14"
feature_size: "S"
---

# Spec — learn-remember-or-not

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-pick-the-answer CONTEXT](../learn-pick-the-answer/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/remember-or-not.md`](../learn-exercises/remember-or-not.md) (the clarified small spec — the starting point; the screenshot's "Flashcards" is merged here), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01, H-05, H-10, Wave 0 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-04, D-08, D-11, D-13, D-16, D-20..D-23, S-01..S-30; this spec adds S-31..S-34), [`learn-kit/spec.md`](../learn-kit/spec.md) and [`learn-pick-the-answer/spec.md`](../learn-pick-the-answer/spec.md) "Implementation status" (house style), the built kit in `lib/features/learn/kit/`, `lib/features/learn/pick_the_answer/`, `lib/features/learn/exercise_screens.dart`, `lib/core/services/pronunciation_service.dart`, `lib/features/word_input/widgets/pronunciation_buttons.dart`, `lib/core/models/film_dialogue.dart`, `vocab-photo-api/src/learn/exercises.json`.

## 1. Context

The learner has a word group selected on the learn page and wants to practise producing its words, not only recognising them. Remember or not is a flashcard drill: the card's front shows only the word's meaning, the learner recalls the word in their head or aloud, flips the card, sees the word, its translation, one example line from a film dialogue if there is one, and can hear it spoken; then they say honestly whether they remembered. A "Not yet" card comes back once at the end of the round. The round ends with a summary of counts and the words not yet remembered.

Why now: `hard-decisions.md` Wave 0 names this exercise as the second user of the shared kit, right after pick-the-answer, because it needs no AI, no network and no owner input. It is the first Stage 2 exercise, the first that uses the speaker and the first that reads film-dialogue lines (D-20 source 1), so it proves the parts of the kit the Step 2 typed exercises reuse.

Committed approach: one `@riverpod` notifier plus one card body inside `ExerciseScaffold` (S-30), with no data beyond the session's words and dialogues. Rounds come from `splitRounds` (3–9, D-13) on the usable words in group order, then the cards of each round are shuffled with `exerciseRandomProvider` (S-27, S-34). The front uses `maskWord` (D-08); the example line comes from a new pure kit helper (S-31); the speaker reuses the app's existing US / UK pronunciation buttons (S-32); the summary is `ResultSummary` with an optional heading for the counts (S-33). Nothing is saved: a self rating is never a word result (D-21, H-05).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- Accent: the app has no "learner's accent" setting; the back shows the same two flag buttons (US, UK) every word row already has, and the learner picks one per tap (S-32). No new setting.
- Shuffle inside a round, not across the group: rounds are split in group order like every other exercise, so which words share a round is stable; only the card order inside a round is random (S-34).
- Front fallback: the stored definition, masked; if the masked definition has no letter left besides "___" (a definition that is just the word), the masked translation; if neither has a letter, the word is not usable.
- Example line: the first line, in dialogue order, of a visible dialogue of the same session linked to the word that holds the word exactly once (the D-20 rule, so fill-the-gaps reuses the helper). Never an AI sentence.
- The flip is one-way and instant: the back replaces the front, no animation, no flip back. A new flip animation would be a new look with no gain for testing.
- Counter "Card n of m": m is the round's size plus the cards put back so far, so it grows by one on each "Not yet".
- Two words with the same meaning give two equal fronts; accepted, because the learner rates themselves and the back shows which word it was.
- The speaker stops when the card changes and when the screen is left; a failure shows the app's existing pronunciation error line in a snackbar and the card stays usable.
- The small spec says there is no error state; S-30 (later, kit-wide) wins: a words load error shows the failed line with Retry.
- Copy chosen here: title "Remember or not", button "Flip", ratings "Remembered" / "Not yet" (first showing) and "Got it" / "Still not" (second), results "Remembered" / "Remembered after repeat" / "Not yet", summary heading "3 remembered, 1 after repeat, 1 not yet".
- Files: `lib/features/learn/remember_or_not/` (S-30); `case 'remember-or-not'` in `exerciseScreen`; `available: true` in `exercises.json` and `exercises.dart` (S-02; stage is already 2).

## 2. Goals

- The learner can practise recalling every usable word of the selected group from its meaning, offline and without typing, and see at the end which words they have not yet remembered.
- Every card is fair: the front never shows the word itself, and the back gives the word with enough context (translation, example line, sound) to fix it in memory.
- The exercise proves the Stage 2 parts of the kit (speaker after reveal, dialogue example lines, summary heading) so the Step 2 typed exercises reuse them instead of writing their own.

## 3. Non-goals

- No saved results and no spaced repetition: a self rating is a hint, not proof (D-21); only Step 3 exams write word results (S-23).
- No word → meaning direction: that is Stage 1 recognition (pick-the-answer, match exercises).
- No swipe, no flip animation and no flip back (D-23): buttons only, one-way reveal.
- No listening or speech-to-text (D-28): the app never checks what the learner said.
- No AI, no network and no dictionary definition (D-16): the exercise must run offline and cost nothing.
- No play on the shared page or the web learn page (D-11).

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Remember or not in Step 2 of the learn page and press Start with a word group selected
**So that** I practise recalling exactly that group's words

### US-02: Recall from the meaning, then flip
**As a** learner
**I want** to see only a word's meaning, try to recall the word, then flip the card to see the word, its translation and an example
**So that** I practise producing the word before I see it

### US-03: Hear the word
**As a** learner
**I want** to tap a speaker on the back of the card to hear the word in the US or UK accent
**So that** I learn how it sounds, without the app ever making a sound on its own

### US-04: Rate myself and repeat what I missed
**As a** learner
**I want** to say whether I remembered the word, and to see a "Not yet" card once more at the end of the round
**So that** I get a second chance at the words I did not recall

### US-05: See my round results
**As a** learner
**I want** a summary after each round with the counts and every word's result
**So that** I know which words I have not remembered yet

### US-06: Clear stop when the group cannot be practised
**As a** learner
**I want** a plain message when my group has too few usable words or the words cannot be read
**So that** I am never left on an empty or broken screen

### US-07: Practise any session without changing it
**As a** learner
**I want** to practise a group of the current session or of a History session, online or offline
**So that** old sessions are useful too, and practising never changes my words

## 5. Acceptance criteria

### Opening and the front

### AC-01 (US-01) — happy path
**Given** the app after this feature, and a selected word group of 5 words to learn that all have a translation
**When** the learner opens the learn page, ticks "Remember or not" in Step 2 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens for that group with the title "Remember or not", and the first card shows the counter "Card 1 of 5", the front (a meaning) and a "Flip" button; no English word, translation, example line, speaker or rating button shows.

### AC-02 (US-02) — domain invariant
**Given** a word "cat" with the stored definition "A cat is a small animal" and the translation "кіт"
**When** its front shows
**Then** the front reads "A ___ is a small animal"; for a word with no stored definition the front is its translation, also with the word masked if it appears there.

### AC-03 (US-02) — domain invariant
**Given** a word whose stored definition is only the word itself (for example "cat" with the definition "Cat"), and another word with no definition and a translation that is only the word itself
**When** the exercise opens
**Then** the first word's front is its translation; the second word is not usable: it gets no card and is not in the summary, and every other word of the group gets a card.

### AC-04 (US-02) — domain invariant
**Given** a group with 13 usable words
**When** the exercise opens
**Then** it runs two rounds, the first holding the first 7 words of the group and the second the other 6; within each round the cards come in a random order, and the same words with the same random seed always give the same order (9 usable words give one round of 9, 10 give 5 + 5; rounds of 3 to 9, never under 3).

### Flip and the back

### AC-05 (US-02) — happy path
**Given** a card showing its front
**When** the learner taps "Flip", or taps the card itself
**Then** the back replaces the front at once: the English word, its translation (no line when the word has none), the example line if there is one, the US and UK speaker buttons, and the rating buttons "Remembered" and "Not yet"; "Flip" is gone, and a further tap on the card changes nothing.

### AC-06 (US-02) — cross-context
**Given** a word "bank" of the session linked to a visible film dialogue of the same session whose lines are "We walked along the river.", "Meet me at the bank, the bank by the bridge." and "The bank opens at nine."
**When** its back shows
**Then** the example line is "The bank opens at nine." with "bank" in bold (the first line that holds the word exactly once); a word with no linked dialogue, linked only to a hidden dialogue, or with no line holding it exactly once shows no example line and no empty space for one; dialogues of other sessions are never used.

### AC-07 (US-03) — happy path
**Given** the back of the card for "give up"
**When** the learner taps the UK speaker button
**Then** "give up" is spoken once in the UK accent; a second tap of either button stops the first and speaks it again in that button's accent.

### AC-08 (US-03) — domain invariant
**Given** any card of the exercise
**When** its front shows, its back appears, or the next card shows
**Then** no sound plays and no speaker button is on the front; sound plays only on a tap of a speaker button, and anything still playing stops when the card changes or the learner leaves the exercise.

### AC-09 (US-03) — error
**Given** the phone cannot play speech (no voice installed or the speech engine fails)
**When** the learner taps a speaker button
**Then** a short message "Could not play pronunciation" (followed by the reason, as on the Words screen) shows at the bottom, the card stays as it was, and the rating buttons still work.

### Rating and the repeat

### AC-10 (US-04) — happy path
**Given** the back of a card on its first showing
**When** the learner taps "Remembered"
**Then** the word counts as "Remembered" and the next card shows its front; after the last card of the round the summary opens.

### AC-11 (US-04) — domain invariant
**Given** a round of 5 cards, on the back of card 2's first showing
**When** the learner taps "Not yet"
**Then** the next card shows with the counter "Card 3 of 6", and the "Not yet" card shows again after all other cards of the round, front first; on that second showing the rating buttons read "Got it" and "Still not".

### AC-12 (US-04) — domain invariant
**Given** the back of a card on its second showing
**When** the learner taps "Got it" or "Still not"
**Then** the card ends with the result "Remembered after repeat" or "Not yet" and never shows again in this round, so every round ends after at most twice its number of cards.

### AC-13 (US-04) — domain invariant
**Given** the last card of a round still to rate on its first showing
**When** the learner taps "Not yet"
**Then** the same card shows again at once, front first, with "Got it" and "Still not" after the flip.

### Summary

### AC-14 (US-05) — happy path
**Given** a round of 5 words rated as 3 "Remembered", 1 "Got it" after a repeat and 1 "Still not"
**When** the summary opens
**Then** its heading reads "3 remembered, 1 after repeat, 1 not yet", and it lists every word of the round once, in the order of its first showing, with "Remembered", "Remembered after repeat" or "Not yet"; it offers "Next round" while rounds remain and "Done" after the last, and Done returns to the learn page (or opens the next ticked exercise, as the learn page does today).

### AC-15 (US-05) — domain invariant
**Given** a round in progress or finished
**When** the learner leaves the exercise with Back or Done
**Then** nothing about the round is kept: no word result is written, no word, translation, definition, group or dialogue changes, and opening the exercise again starts at round 1 with the cards shuffled afresh.

### Empty and error states

### AC-16 (US-06) — error
**Given** a selected group with fewer than 3 usable words (including a group whose words were all deleted)
**When** the learner starts the exercise
**Then** only the message "Not enough words for this exercise" and a "Back" button show, no round starts, and Back returns to the learn page.

### AC-17 (US-06) — error
**Given** the session's words cannot be read when the exercise opens
**When** the screen shows
**Then** only the line "Could not load the exercise. Check the connection and try again." and a "Retry" button show; when Retry succeeds, round 1 starts with all usable words and their example lines.

### Sessions and people

### AC-18 (US-07) — cross-context
**Given** the learn page opened for a History session with a selected group and film dialogues
**When** the learner plays the exercise to the end
**Then** the cards use that session's group, words and dialogues only, and the History session is unchanged afterwards (same words, same groups, same dialogues, same last-changed time).

### AC-19 (US-07) — cross-context
**Given** the phone is offline
**When** the learner starts and plays the exercise, including the speaker
**Then** it works exactly as online; the exercise never asks the server for anything.

### AC-20 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 2
**Then** Remember or not is listed with the same name and step as in the app, and the page offers no way to play it; only the learner, in the app, can play it.

### AC-21 (US-02) — happy path
**Given** a front, a translation or an example line too long for one line (for example a two-sentence definition), or a multi-word entry such as "give up"
**When** the card shows
**Then** the full text wraps onto more lines and stays readable, nothing is cut, the card scrolls if it does not fit, and a multi-word entry is one card spoken as a whole.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Network calls made by the exercise | 0 | widget test with a `learnApiService` override that fails on any call; code review |
| Sounds played without a tap | 0 | widget test with a fake `pronunciationServiceProvider` counting `speak` calls across front, flip, rating and next card |
| Start to first card (19-word group, release build, mid-range Android phone) | ≤ 300 ms | manual check with the profile overlay before ship |
| Determinism | same words + same random seed → same usable words, rounds and card order, 100% | unit tests with an overridden `exerciseRandomProvider` (S-27) |
| Round ends | every round ends after ≤ 2 × its cards showings, for any rating sequence | unit test over all rating sequences of a 3-card round and random sequences of a 9-card round |
| Test coverage | every AC has a unit or widget test; AC-20 by the existing Worker learn-page test | `tool/test.sh changed` |
| Visual frame | uses `ExerciseScaffold`, `ResultSummary` and `PronunciationButtons` only; no own loading, error, summary or speaker code | review |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words and dialogue lines, read from the phone only.
- **Personal data touched:** none new; nothing leaves the phone and nothing is written. Speech is produced on the device.
- **AuthZ/AuthN impact:** none. App-only screen; no new service, no shared-page capability.
- **Abuse cases:**
  - Partner tries to play from a web link: the web learn page has no play surface (AC-20).
  - A word, definition or dialogue line with odd text (very long, markup-like): shown as plain text, wrapped (AC-21); only the word is bolded by the app, nothing is parsed.
  - Practising a History session altering it: read-only by construction (AC-18).
  - The app making sound in a quiet place: only on a tap (AC-08).
- **Security review:** N/A — no new data flow, no network, no storage.

## 7. Metrics / KPIs

The app has no usage analytics; these are checked at review and by the owner's own use.

- **Kit reuse** — baseline: 1 exercise on the kit. Target: this exercise uses `ExerciseScaffold`, `ResultSummary`, `splitRounds`, `maskWord`, `exerciseWordsProvider`, `exerciseRandomProvider` and the new S-31..S-33 parts with no copy of their logic, checked at `sdd:review`.
- **Cards that give the word away** (the word readable on a front) reported by the owner — baseline: n/a. Target: 0 in the first 30 days after ship.
- **Groups that can be practised** (owner's sessions where the selected group shows a round, not "Not enough words") — baseline: 0 (exercise not available). Target: every group of 3+ words to learn, checked on the owner's sessions within 7 days of ship.

## 8. Open questions

- [ ] Should "Not yet" ratings ever feed the Step 3 word result (for example "Practise repeat words")? Default now: no, never saved (D-21, H-05). — owner: Maksym, due: any time; a later small change once Step 3 exams ship.
- [ ] Should the app get a "my accent" setting so exercises show one speaker instead of the US / UK pair? Default now: no setting; the two existing flag buttons (S-32). — owner: Maksym, due: any time; a setting is a visible change (rule 3).
