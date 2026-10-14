---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-14"
feature_size: "S"
---

# Spec — learn-pick-the-answer

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/pick-the-answer.md`](../learn-exercises/pick-the-answer.md) (the clarified small spec — the starting point), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01, H-10 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-12..D-17, D-22, D-42, S-01..S-24; this spec adds S-25..S-30), [`learn-kit/spec.md`](../learn-kit/spec.md) incl. "Implementation status", the built kit in `lib/features/learn/kit/`, `lib/features/learn/exercise_screens.dart`, `lib/features/learn/exercises.dart`, `lib/core/story/word_grouping.dart` (`wordsToLearn`, `groupWords`). No network service is used (`lib/core/services/learn_api_service.dart` was read to confirm that none is needed).

## 1. Context

The learner has a word group selected on the learn page and wants a quick, no-typing check that they recognise its words. Pick the right answer is that check: for each word of the group one question with four options, the first tap final, a green or red mark at once, and a summary per round. It is the first Step 1 exercise built on the shared exercise kit and the first that turns a "Coming soon" row of the Learn list into a playable exercise.

Why now: the kit (learn-kit) is built and tested but no exercise uses it, and every kit behaviour that is only testable end to end (opening from Start, Back mid-round, the summary, several ticked exercises in a row) waits for a first user. `hard-decisions.md` Wave 0 names this exercise first because it needs no AI, no network and no owner input.

Committed approach: one `@riverpod` notifier plus one round body on top of the kit, with no data of its own beyond the session's words. Questions come from the kit's pure `buildQuestion` (D-14, S-09), rounds from `splitRounds` (3–9 words, D-13), the frame and summary from `ExerciseScaffold` and `ResultSummary`, the words from `exerciseWordsProvider` (S-08). The only kit additions are ones the Quiz needs too (S-26, S-27, S-28). Nothing is saved (D-04; only Step 3 writes word results, S-23).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- Speaker: none in v1, as the clarified small spec says. D-22 lists pick-the-answer among speaker users; the later, clarified spec wins and D-22's mention is read as "later".
- Usable words are decided once, before rounds are split, by asking the builder for both question kinds (S-25), so alternation never breaks inside a round.
- Kind alternation restarts with kind A in every round (S-29).
- Two rows that share an English word, or share a meaning, are never right and wrong options of the same question (S-26) — the small spec forbids equal options but not two right answers with different text.
- Copy chosen here: the lines "Pick the translation" (kind A) and "Pick the word" (kind B), the counter "Question 2 of 5", the button "Next", the summary results "Right" and "Missed".
- Files: `lib/features/learn/pick_the_answer/` (S-30); the `exerciseScreen` switch gets `case 'pick-the-answer'`; `available: true` is flipped in `exercises.json` and `exercises.dart` (S-02; stage is already 1).

## 2. Goals

- The learner can practise recognising every usable word of the selected group, in both directions (word → translation, meaning → word), without typing and without a network.
- The learner always gets a fair question: exactly one right option, never two options that read the same, never a second option that is also right.
- The exercise proves the shared kit end to end, so later exercises add only their own body and notifier.

## 3. Non-goals

- No saved results: a Stage 1 exercise shows its results in the round summary only (D-04, S-23 — only Step 3 writes word results).
- No AI and no network call of any kind, including no dictionary definition (D-16): the exercise must run offline and cost nothing.
- No speaker or pronunciation in v1: it adds a second interaction to a recognition drill; a later spec may add it after the answer, per D-22.
- No play on the shared page or the web learn page (D-11): the partner has no app and v1 has no live state.
- No second try and no hint: the first tap is final (D-17).

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Pick the right answer on the learn page and press Start with a word group selected
**So that** I practise exactly that group's words

### US-02: Answer by one tap
**As a** learner
**I want** to see a word or a meaning with four options and tap the one I think is right
**So that** I find out at once whether I recognise the word

### US-03: Fair options
**As a** learner
**I want** the options to be different from each other and only one of them to be right
**So that** a miss always means I did not know the word

### US-04: See my round results
**As a** learner
**I want** a summary after each round listing each word as right or missed
**So that** I know which words to look at again

### US-05: Clear stop when the group cannot be practised
**As a** learner
**I want** a plain message when my group has too few usable words or the words cannot be read
**So that** I am never left on an empty or broken screen

### US-06: Practise any session without changing it
**As a** learner
**I want** to practise a group of the current session or of a History session
**So that** old sessions are useful too, and practising never changes my words

## 5. Acceptance criteria

### Opening and the question

### AC-01 (US-01) — happy path
**Given** the app after this feature, and a selected word group of 5 words to learn that all have a translation, in a session with no other words
**When** the learner opens the learn page, ticks "Pick the right answer" in Step 1 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens for that group with the title "Pick the right answer", and question 1 of round 1 shows the counter "Question 1 of 5", the line "Pick the translation", the first word of the group and four options.

### AC-02 (US-03) — domain invariant
**Given** any question of the exercise
**When** it shows
**Then** it has exactly four options, no two of them are equal ignoring case and extra spaces, exactly one is the right answer, and the right answer's place among the four varies between questions (it is not always the first).

### AC-03 (US-02) — happy path
**Given** a round of 5 usable words
**When** the questions show one after another
**Then** they follow group order; questions 1, 3 and 5 show the English word with four translations ("Pick the translation"); questions 2 and 4 show the word's meaning with four English words ("Pick the word"). The next round starts again with a word-to-translation question.

### AC-04 (US-02) — domain invariant
**Given** a meaning-to-word question for the word "cat" whose stored definition is "A cat is a small animal"
**When** it shows
**Then** the meaning reads "A ___ is a small animal"; for a word with no stored definition the meaning shown is its translation.

### AC-05 (US-02) — happy path
**Given** a question on screen with no option tapped
**When** the learner taps the right option
**Then** that option turns green, the other options can no longer be tapped, the word counts as right, and a "Next" button shows.

### AC-06 (US-02) — domain invariant
**Given** a question on screen with no option tapped
**When** the learner taps a wrong option
**Then** the tapped option turns red and the right option turns green, the word counts as missed, no option can be tapped again (a later tap changes nothing), and a "Next" button shows.

### AC-07 (US-02) — happy path
**Given** a question already answered
**When** the learner presses "Next"
**Then** the next question of the round shows; after the last question of the round, "Next" opens the round summary instead.

### Options

### AC-08 (US-03) — domain invariant
**Given** a group in which two words have the translations "Кіт" and "кіт " and a third word is asked as a word-to-translation question
**When** its options are built
**Then** at most one of the two equal translations appears, and another word's translation takes the free place, so the four options stay different.

### AC-09 (US-03) — domain invariant
**Given** two words of the session that share a meaning (for example "cat" and "kitty", both with the translation "кіт" and no definition), or two rows with the same English word and different translations (for example "bank" — "банк" and "bank" — "берег")
**When** a question is built for one of them
**Then** the other row never appears as a wrong option of that question, so no question has two right answers.

### AC-10 (US-03) — cross-context
**Given** a selected group of 3 words in a session that has 10 words to learn in all
**When** options are built
**Then** wrong options come from the other words of the group first and are topped up from the session's other 7 words; words of any other session are never used.

### Usable words, rounds and empty states

### AC-11 (US-05) — domain invariant
**Given** a group in which one word has a definition but no translation, and one word's question cannot get three wrong options that are different and not also right
**When** the exercise opens
**Then** both words are left out: they get no question and do not appear in the summary; every other word of the group is asked.

### AC-12 (US-05) — error
**Given** a selected group with fewer than 3 usable words (including a group whose words were all deleted, or a session whose words cannot give four different options)
**When** the learner starts the exercise
**Then** only the message "Not enough words for this exercise" and a "Back" button show, no round starts, and Back returns to the learn page.

### AC-13 (US-04) — domain invariant
**Given** a group with 13 usable words
**When** the exercise opens
**Then** it runs two rounds, the first of 7 words and the second of 6, in group order; 9 usable words give one round of 9 and 10 give 5 + 5 (rounds of 3 to 9, never under 3).

### AC-14 (US-05) — error
**Given** the session's words cannot be read when the exercise opens
**When** the screen shows
**Then** only the line "Could not load the exercise. Check the connection and try again." and a "Retry" button show; when Retry succeeds, round 1 starts with all usable words.

### Summary

### AC-15 (US-04) — happy path
**Given** the last question of a round answered
**When** the summary opens
**Then** it lists every word of that round in question order, each with "Right" (right on the first tap) or "Missed"; it offers "Next round" while rounds remain and "Done" after the last, and Done returns to the learn page (or opens the next ticked exercise, as the learn page does today).

### AC-16 (US-04) — domain invariant
**Given** a round in progress or finished
**When** the learner leaves the exercise with Back or Done
**Then** nothing about the round is kept: no word result is written, no word, translation, definition, group or dialogue changes, and opening the exercise again starts at round 1 with freshly built questions.

### Sessions and people

### AC-17 (US-06) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner plays the exercise to the end
**Then** questions use that session's group and words only, and the History session is unchanged afterwards (same words, same groups, same last-changed time).

### AC-18 (US-06) — cross-context
**Given** the phone is offline
**When** the learner starts and plays the exercise
**Then** it works exactly as online; the exercise never asks the server for anything.

### AC-19 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 1
**Then** Pick the right answer is listed with the same name and step as in the app, and the page offers no way to play it; only the learner, in the app, can play it.

### AC-20 (US-02) — happy path
**Given** a meaning or an option text too long for one line (for example a two-sentence definition)
**When** the question shows
**Then** the full text wraps onto more lines and stays readable; nothing is cut, and the screen scrolls if it does not fit.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Network calls made by the exercise | 0 | widget test with a `learnApiService` override that fails on any call; code review |
| Start to first question (19-word group, release build, mid-range Android phone) | ≤ 300 ms | manual check with the profile overlay before ship |
| Determinism | same words + same random seed → same usable words, rounds, kinds, options and right places, 100% | unit tests with an overridden `exerciseRandomProvider` (S-27) |
| Fairness | 0 questions with two equal options or two right options over 1000 random seeds on a fixture of 30 words incl. shared meanings and homographs | unit test of `buildQuestion` |
| Test coverage | every AC has a unit or widget test; AC-19 by the existing Worker learn-page test | `tool/test.sh changed` |
| Visual frame | uses `ExerciseScaffold` and `ResultSummary` only; no own loading, error or summary code | review |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, read from the phone only.
- **Personal data touched:** none new; nothing leaves the phone and nothing is written.
- **AuthZ/AuthN impact:** none. App-only screen; no new service, no shared-page capability.
- **Abuse cases:**
  - Partner tries to play from a web link: the web learn page has no play surface (AC-19).
  - A word or definition with odd text (very long, markup-like): shown as plain text, wrapped (AC-20); no parsing.
  - Practising a History session altering it: read-only by construction (AC-17).
- **Security review:** N/A — no new data flow, no network, no storage.

## 7. Metrics / KPIs

The app has no usage analytics; these are checked at review and by the owner's own use.

- **Kit reuse** — baseline: 0 exercises on the kit. Target: this exercise uses `ExerciseScaffold`, `ResultSummary`, `splitRounds`, `buildQuestion` and `exerciseWordsProvider` with no copy of their logic, checked at `sdd:review`.
- **Unfair questions reported by the owner** (two right answers, equal options) — baseline: n/a. Target: 0 in the first 30 days after ship.
- **Groups that can be practised** (owner's sessions where the selected group shows a round, not "Not enough words") — baseline: 0 (exercise not available). Target: every group of 3+ words with translations, checked on the owner's sessions within 7 days of ship.

## 8. Open questions

- [ ] CLAUDE.md rule 3 must list this visible change: the "Pick the right answer" row becomes tickable and its exercise screen (question, options with green/red marks, Next, summary) appears. Only the owner edits CLAUDE.md. Default now: build it (H-10/S-01 approved the Learn list and "all exercises implemented"); flip `available` only after the owner's line is added. — owner: Maksym, due: before `sdd:implement learn-pick-the-answer` ships the flip.
- [ ] Should a speaker button appear after the answer (D-22 lists this exercise)? Default now: no speaker in v1, per the clarified small spec. — owner: Maksym, due: any time; a later small change.
