---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-15"
feature_size: "S"
---

# Spec — learn-quiz

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-fill-the-gaps CONTEXT](../learn-fill-the-gaps/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/quiz.md`](../learn-exercises/quiz.md) (the clarified small spec — the starting point), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-05, H-08, Wave 3 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-05, D-12, D-14..D-18, D-20, D-22, D-31..D-34, D-41..D-43, S-01..S-52; this spec adds S-53..S-56), "Implementation status" of [`learn-kit/spec.md`](../learn-kit/spec.md) (AC-35..AC-38, the word result), [`learn-pick-the-answer/spec.md`](../learn-pick-the-answer/spec.md) and [`learn-fill-the-gaps/spec.md`](../learn-fill-the-gaps/spec.md), kit code in `lib/features/learn/kit/` (`question_builder.dart`, `choice_options.dart`, `gap_question.dart`, `typed_answer_field.dart`, `typed_match.dart`, `result_summary.dart`, `exercise_phase.dart`, `exercise_scaffold.dart`, `exercise_random.dart`, `exercise_words.dart`, `sentence_check.dart` (`examLabel`, `examSummaryText`)), `lib/core/services/exam_result_sink.dart`, `lib/core/models/word_result.dart`, `lib/features/learn/pick_the_answer/`, `lib/features/learn/fill_the_gaps/`. House style: [`learn-sentence-patterns/spec.md`](../learn-sentence-patterns/spec.md).

## 1. Context

The learner has practised a word group in Steps 1 and 2 and wants to know which of its words they really know. The Quiz is a short mixed test: up to seven questions, one per word, alternating a choice question (four options; kind A word → translation, kind B meaning → word) and a gap question (a sentence with "___", the translation as the cue, the word typed). It is an exam: the first tap or Send is the answer and is locked, there is no hint, no retry, no speaker and no "Show answer", and nothing shows right or wrong until the summary. Each asked word ends as **known** or **repeat**, and that word result is saved on the session as soon as the answer is given. The summary shows "N of n known", each word's label, and for repeat words the right answer next to the learner's; "Repeat" runs a new attempt over only the repeat words.

Why now: `hard-decisions.md` Wave 3 builds the Quiz first among the exams because it reuses two built builders and costs no sentence check. Everything it needs exists: the choice builder and its widget (S-09, S-25, S-26, S-28), the gap loader, prompt and exam-mode typed field (S-11, S-43..S-45), and the owner-approved `WordResult` with its `ExamResultSink` (S-01, S-22, S-23), which no exercise writes yet. Because the Quiz is the first writer, how an exam turns a final answer into a saved word result, and what its summary shows, is fixed here for the three exams that follow (translate-sentences, own-sentences, explain-to-friend) — S-55.

Committed approach: one `@riverpod` notifier plus one body on top of the kit (S-30). On open the notifier reads the group's words (`exerciseWordsProvider`, S-08) and the session's dialogues (`exerciseDialoguesProvider`, S-31), works out which words can take a choice question and asks `loadGapQuestions` (S-44) once for the gap questions, catching a Worker failure to run choice-only. It samples and orders the questions with the kit's `Random` (S-27) by the rule of S-54, builds them all once, and on each final answer records the word's result through the sink at once (S-55). The summary uses two optional kit additions: a detail line per word and a second button (S-56).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- **Usable words (S-53).** A candidate is a word to learn of the group with a non-empty trimmed word, translation and row id. It can take a choice question when `buildQuestion` gives one for **both** kinds (S-25, so the kind order can never hit a null), and a gap question when `loadGapQuestions` returns one. Usable = either. Fewer than 3 candidates shows "Not enough words for this exercise" without any Worker call; fewer than 3 usable words shows the same line.
- **Sample, order and kinds (S-54).** n = min(7, usable). The usable words are shuffled once and the first n are the attempt's words; the positions are then filled by walking that order: an odd position takes the first remaining word that can take a choice question (else the first remaining word, as a gap), an even position takes the first remaining word with a gap question (else the first remaining word, as a choice). Choice questions alternate kind A, B, A… in their own order, starting with A. When every word can take both, positions 1, 3, 5, 7 are choice and 2, 4, 6 are gap, exactly as the small spec says; the walk only decides the cases the small spec leaves to "a word with no usable sentence gets choice".
- **No rounds.** One attempt is one sequence of at most 7 questions; `splitRounds` is not used, so there is no "Round n of m" and no "Next round". The counter is "Question n of m" (m = the attempt's size).
- **Gap failure degrades, it does not block (narrows D-05, as quiz.md and S-44 say).** Any failure of the gap load (offline, timeout, the day's data allowance, too many requests, no exercise storage, a broken reply) is caught; the attempt is built from choice questions only — dialogue gaps found before the failure are dropped too, so the rule is simply "no gap questions" — and the line "Gap questions are unavailable" shows under the counter on every question. No Retry, no day-limit line. A failure to read the session's words or dialogues is not a Worker failure: it shows the frame's error line with Retry (S-30).
- **Exam rules on screen (D-34, D-41, D-43).** Choice: `ChoiceOptions(reveal: false)` (only the picked option is marked chosen). Gap: `GapPrompt(question)` never revealed, the cue shows (quiz.md lists it), `TypedAnswerField(mode: exam)` keyed per attempt and question. No speaker (D-22 does not list the Quiz after the conflict resolution). An empty Send is not an answer (the kit field ignores it); "left blank" in quiz.md is the Skip.
- **Skip.** A gap question uses the exam field's own "Skip" (unchanged kit, S-11). A choice question gets a "Skip" button below the options, the same text button; it disappears once the word is final. Skip counts as repeat.
- **The exam-result pattern (S-55).** The notifier records `quiz`, the word's row id, the session id (null = current) and the label through `examResultSinkProvider` in the same step that makes the answer final (tap, Send or Skip), once per question of an attempt, without waiting for it; nothing is recorded at the summary, on Next, on Done or on Back; a word never answered gets nothing. The labels: choice right → known, else repeat; typed right or almost → known, wrong or Skip → repeat. Stored results are not read by the Quiz in v1 (the sample ignores them; §8).
- **Summary (S-56).** Heading "N of n known" (S-33); the attempt's words in asked order; result "Known" or "Repeat"; for repeat a detail line "Answer: <right> · Yours: <given>" or "Answer: <right> · Skipped" (right = the right option or the word; given = the picked option or the typed text, trimmed). Buttons: "Repeat" (only when a word is repeat) and "Done" (always). This needs two additive kit changes: `WordOutcome.detail` (shown as a second line) and an optional extra summary button (`againLabel` + `onAgain`) on `ResultSummary`, `ExerciseSummary` and `ExerciseScaffold`; with the defaults (null) every built exercise looks the same as today.
- **Repeat attempt.** "Repeat" starts a new attempt over exactly the words labelled repeat in the summary just shown, by the same S-54 rule (so it is reshuffled and the kinds and options are rebuilt with the same `Random`), with no 3-word minimum and from the data already loaded (no new Worker call, no new read). Its results are recorded again (newest wins, S-22) and its summary replaces the earlier one. Words known in the earlier attempt are not asked and keep their saved result.
- **Leaving.** Back at any point returns to the learn page with no dialog; results already recorded stay, nothing else is kept; opening the Quiz again starts a fresh attempt with a new sample.
- **Copy chosen here:** title "Quiz", counter "Question n of m", "Pick the translation" / "Pick the word" (S-29), "Type the missing word" (fill-the-gaps), "Skip", "Next", "Gap questions are unavailable", heading "N of n known", results "Known" / "Repeat", details as above, buttons "Repeat" / "Done". The frame's lines stay ("Not enough words for this exercise", the load error line).
- **Files:** `lib/features/learn/quiz/` (`quiz_notifier.dart`, `quiz_screen.dart`, S-30); `result_summary.dart`, `exercise_phase.dart` and `exercise_scaffold.dart` gain the optional fields of S-56, and `result_summary.dart` the pure `examHeading(known, total)` of S-55; `case 'quiz'` in `exerciseScreen`; `available: true` in `exercises.json` (Worker) and `exercises.dart` (S-02). Unchanged: `question_builder.dart`, `choice_options.dart`, `gap_question.dart`, `typed_answer_field.dart`, `typed_match.dart`, `exam_result_sink.dart`, `word_result.dart`, the Worker code.

## 2. Goals

- The learner can take a short, fair test over any selected group that tells them, word by word, which words are known and which to repeat.
- Every answered word leaves a saved word result on its session the moment it is answered, so a test left halfway still counts what was done, and nothing is saved for what was not.
- The way an exam records word results and shows its summary is fixed once, so the three sentence exams record and show results the same way.

## 3. Non-goals

- No hint, retry, speaker, "Show answer" or right-or-wrong colour during the attempt (D-34, D-41, D-43).
- No use of stored results inside the Quiz in v1: the sample does not prefer repeat words and the summary shows only this attempt (§8).
- No screen that lists saved results, and no effect of results on the word row, sharing, exports or the lightning icons (S-22, learn-kit AC-37).
- No play on the shared page or the web learn page (D-11, H-07).
- No Worker change and no change to the choice builder, the gap loader or the typed field (§1).

## 4. User stories

### US-01: Start a quiz for a group
**As a** learner
**I want** to tick Quiz in Step 3 and press Start with a word group selected
**So that** I am tested on exactly that group's words

### US-02: Answer mixed questions under exam rules
**As a** learner
**I want** up to seven questions, choice and gap mixed, each answered once with no hint and no feedback until the end
**So that** the result says what I really know

### US-03: Skip what I do not know
**As a** learner
**I want** a Skip on every question
**So that** I can move on without guessing, and the word is marked to repeat

### US-04: See which words I know
**As a** learner
**I want** a summary with "N of n known", each word as known or repeat, and the right answer next to mine for each repeat word
**So that** I see what to work on

### US-05: Repeat only the weak words
**As a** learner
**I want** a "Repeat" button that tests me again on only the repeat words
**So that** I can turn them into known words at once

### US-06: Keep my results
**As a** learner
**I want** each answered word's result saved on the session at once, also when I leave the quiz early or the session is from History
**So that** the app knows which words I know, without changing my words

### US-07: A quiz even without the connection
**As a** learner
**I want** the quiz to run with choice questions only when gap sentences cannot be loaded, and a plain message when the group is too small
**So that** a bad connection or a small group never leaves me on a broken screen

## 5. Acceptance criteria

### Opening and the question set

### AC-01 (US-01) — happy path
**Given** the app after this feature and a selected word group of 9 words to learn, each with a translation, each able to take a choice question of both kinds and a gap question
**When** the learner opens the learn page, ticks "Quiz" in Step 3 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the Quiz opens with the title "Quiz" and "Question 1 of 7", and the attempt asks 7 questions on 7 different words of the group: questions 1, 3, 5, 7 are choice (kinds A, B, A, B) and 2, 4, 6 are gap questions.

### AC-02 (US-01) — domain invariant
**Given** groups with 3, 5, 6, 7 and 12 usable words
**When** the Quiz opens
**Then** it asks 3, 5, 6, 7 and 7 questions, one per word, never the same word twice, in one sequence with no rounds ("Next round" never shows).

### AC-03 (US-07) — error
**Given** a selected group with fewer than 3 words to learn that have a translation
**When** the learner starts the Quiz
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked.

### AC-04 (US-07) — error
**Given** a selected group with 3 or more words to learn with a translation, of which fewer than 3 can take either a choice question or a gap question
**When** the learner starts the Quiz
**Then** only "Not enough words for this exercise" and "Back" show; Back returns to the learn page.

### AC-05 (US-02) — domain invariant
**Given** an attempt whose shuffled words are, in order, a and b (choice only: no gap sentence), c (both) and d (gap only: no choice question can be built)
**When** the questions are laid out
**Then** they are a as choice kind A, c as gap, b as choice kind B, d as gap; a group whose usable words are all choice-only gives only choice questions (kinds A, B, A…), and one whose usable words are all gap-only gives only gap questions; a word that can take neither is never asked and is not in the summary.

### AC-06 (US-02) — domain invariant
**Given** the same group, the same session and the same random seed
**When** the Quiz opens twice
**Then** both attempts ask the same words in the same order with the same kinds and the same options in the same order; the session's saved word results do not change which words are asked.

### Where the questions come from

### AC-07 (US-02) — cross-context
**Given** a group of 8 words to learn with translations, 3 of them with a linked film dialogue line that makes a fair gap sentence
**When** the Quiz opens
**Then** those 3 gap sentences come from the dialogue lines; the Worker is asked once, for the 5 others only, while the frame's loading state shows; when every word has a dialogue gap the Worker is not asked at all; a word without a translation is never sent; the same group opened again within 30 days takes nothing from the daily data allowance.

### AC-08 (US-07) — error
**Given** the phone is offline (or the Worker fails, times out, has no exercise storage, says the day's data allowance is used up, or says requests are too frequent) while the gap sentences load
**When** the Quiz opens
**Then** the attempt still starts, every question is a choice question (kinds A, B, A…), the line "Gap questions are unavailable" shows under the counter on every question, and no Retry, day-limit or rate-limit line shows; words that could only take a gap are not asked; if fewer than 3 words can take a choice question, "Not enough words for this exercise" shows instead.

### AC-09 (US-07) — error
**Given** the session's words or dialogues cannot be read
**When** the Quiz opens
**Then** only "Could not load the exercise. Check the connection and try again." and "Retry" show; Retry reads them again and, on success, question 1 shows.

### AC-10 (US-06) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner takes the Quiz
**Then** only that session's words and dialogues are used and sent, and the session's words, groups, dialogues and last-changed time are unchanged afterwards; its History position does not move.

### Answering

### AC-11 (US-02) — happy path
**Given** a choice question of kind A for "receive"
**When** it shows
**Then** "Pick the translation", the word, four options and "Skip" show, with no keyboard, no speaker and no colour; for kind B the line is "Pick the word" and the prompt is the word's meaning with the word itself hidden as "___".

### AC-12 (US-02) — domain invariant
**Given** a choice question
**When** the learner taps an option
**Then** only that option is marked as chosen (neither green nor red, and the right option is not shown), further taps on any option change nothing, "Skip" disappears and "Next" shows.

### AC-13 (US-02) — happy path
**Given** a gap question for "receive"
**When** it shows
**Then** "Type the missing word", the sentence with one "___", the word's translation under it, and a field with the keyboard open (no autocorrect, no suggestions, the action key is Send) and "Skip" show; no first letter, letter count, speaker or "Show answer".

### AC-14 (US-02) — error
**Given** a gap question for "receive"
**When** the learner sends "accept"
**Then** there is no second try, no first-letter hint and no "Answer:" line; the field becomes read-only, nothing shows right or wrong, and "Next" shows; the word is repeat.

### AC-15 (US-02) — domain invariant
**Given** a gap question for "receive"
**When** the learner sends "recieve", " Receive ", "receives" or "receiv"
**Then** "recieve", " Receive " and "receiv" make the word known (a one-letter slip on a word of 5 or more letters counts as right) and "receives" makes it repeat (another form of the word is wrong); in every case the screen shows no verdict before the summary.

### AC-16 (US-02) — error
**Given** a gap question with an empty field or only spaces
**When** the learner presses Send
**Then** nothing happens: it is not an answer, the field stays open and "Skip" stays.

### AC-17 (US-03) — happy path
**Given** any question before it is answered
**When** the learner taps "Skip"
**Then** the question cannot be answered any more, "Next" shows, and the word is repeat.

### AC-18 (US-02) — happy path
**Given** an answered or skipped question 4 of 7
**When** the learner taps "Next"
**Then** question 5 shows; there is no way back to an earlier question; after the last question "Next" opens the summary.

### Saving word results

### AC-19 (US-06) — cross-context
**Given** a Quiz on a session
**When** a question's answer becomes final (an option tapped, a non-empty answer sent, or Skip)
**Then** at that moment exactly one word result is saved on that session for that word, from the exam "quiz", with the label known or repeat as the summary will show it, and the time; the learner does not wait for it and sees nothing about it.

### AC-20 (US-06) — domain invariant
**Given** a Quiz of 7 questions
**When** the learner taps Next, opens the summary or taps Done
**Then** no word result is saved by these taps; over the whole attempt exactly 7 results are saved, one per asked word, and none for a word of the group that was not asked.

### AC-21 (US-06) — domain invariant
**Given** a Quiz where 3 of 7 questions are answered or skipped
**When** the learner leaves with Back
**Then** exactly those 3 word results are saved and the other 4 words have none from this attempt (no label at all, never repeat); opening the Quiz again starts a fresh attempt at question 1 with a new sample.

### AC-22 (US-06) — cross-context
**Given** a session with saved word results from the Quiz
**When** the learner shares, publishes, exports (any of the five formats) or copies its words, or the lightning icons are shown
**Then** none of them contains or reacts to the results, and the session's last-changed time and History order did not move because of them.

### Summary and Repeat

### AC-23 (US-04) — happy path
**Given** an attempt of 7 questions where 5 words ended known, "receive" was answered "accept" on a gap, and "borrow" was skipped on a choice question whose right option was "позичати"
**When** the summary opens
**Then** it shows "5 of 7 known", then the 7 words in the order they were asked, each as "Known" or "Repeat"; under "receive" the line "Answer: receive · Yours: accept", under "borrow" the line "Answer: позичати · Skipped"; known words have no second line; the buttons are "Repeat" and "Done".

### AC-24 (US-04) — happy path
**Given** an attempt where every word ended known
**When** the summary opens
**Then** it shows "n of n known", every word as "Known", and only "Done"; Done returns to the learn page (or opens the next ticked exercise, as today).

### AC-25 (US-05) — happy path
**Given** a summary with exactly 2 repeat words
**When** the learner taps "Repeat"
**Then** a new attempt of exactly those 2 words starts at "Question 1 of 2" (the 3-word minimum does not apply), laid out by the same rule as AC-05, under the same exam rules, with no new Worker call and no loading state; its answers save new word results (the newest one per word counts), and its summary replaces the earlier one.

### AC-26 (US-05) — domain invariant
**Given** a Repeat attempt
**When** it runs and ends
**Then** words known in the earlier attempt are not asked and keep their earlier result; a Repeat attempt with repeat words again offers "Repeat" again; a Repeat attempt in a quiz whose gap sentences were unavailable still shows "Gap questions are unavailable" and asks only choice questions.

### People

### AC-27 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 3
**Then** Quiz is listed with the same name and step as in the app and cannot be played there; no word result can come from the web, because only the learner's app takes the Quiz and saves results.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per load Retry) | 0 when there are fewer than 3 candidates or every candidate has a dialogue gap; else exactly 1 sentence data call holding only the candidates without one; 0 checks | widget test with a counting `learnApiService` fake |
| Worker calls per Repeat attempt | 0 | widget test with a counting fake |
| Word results per attempt | exactly 1 `record` per asked word, at the moment its answer is final; 0 for Next, the summary, Done, Back, Repeat itself and unasked words; exercise id `quiz`; the quiz's session id passed through | notifier test with a recording `ExamResultSink` fake |
| Tap / Send / Skip to "Next" shown | ≤ 100 ms, never waiting for the result save | widget test pumps one frame with a sink whose `record` never completes |
| Start to question 1, cached group, good network | ≤ 1.5 s | manual check before ship |
| Determinism | same seed + same session → same words, order, kinds and options, 100% | notifier test with `Random(seed)` over `exerciseRandomProvider` |
| Feedback leak | 0 right/wrong marks, answer lines or colours before the summary | widget tests over both question types and all answer kinds |
| Kit reuse | 0 changed lines in `question_builder.dart`, `choice_options.dart`, `gap_question.dart`, `typed_answer_field.dart`, `typed_match.dart`, `exam_result_sink.dart`, `word_result.dart`; `result_summary.dart`, `exercise_phase.dart`, `exercise_scaffold.dart` only gain optional fields with null defaults (plus `examHeading`) | `git diff` at `sdd:review` |
| Test coverage | every AC has a unit or widget test; AC-27 by the Worker learn-page test; AC-22 by the existing learn-kit tests plus one Quiz-written result | `tool/test.sh changed` |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, translations and test answers.
- **Personal data touched:** the word results (row id, exam, label, time) saved on the learner's own session on the device, as S-22 already allows; the learner's typed and picked answers are shown in the summary only and never stored or sent. Words and translations without a dialogue gap go to the Worker once per group, as fill-the-gaps already does.
- **AuthZ/AuthN impact:** none new. The data call stays behind the app's secret (S-14); results are written only by the app on the device (S-23); no play surface on the web.
- **Abuse cases:**
  - Partner tries to take the Quiz from a web link: the web learn page lists it only (AC-27).
  - Results leaking through sharing or exports: results are never part of the word row or any shared or exported form (AC-22).
  - A learner retaking the Quiz to overwrite repeat with known: allowed and intended — the newest result wins (S-22); there is no score to inflate.
  - Draining the data allowance by reopening: repeat opens are cache hits and cost nothing; Repeat attempts make no call (AC-07, AC-25).
- **Security review:** N/A — no new data flow, route, secret or storage beyond the approved word result.

## 7. Metrics / KPIs

The app has no usage analytics; checked at review from the owner's own use, the saved word results in a debug run, and the Worker's `learn data` log lines (S-24).

- **Groups that can take a quiz** (owner's groups showing question 1, not "Not enough words…") — baseline: 0 (not available). Target: at least 9 of 10 within 14 days of ship.
- **Quizzes with gap questions** (attempts that hold at least one gap question, over all first attempts) — baseline: 0. Target: ≥ 90% within 30 days of the owner's learn-kit deploy; below that, check the kind `sentence` rejections (S-43, S-44).
- **Answered words with a saved result** (saved Quiz results over answered questions, debug run) — baseline: 0. Target: 100% from the first release.
- **Repeat words turned known** (words repeat in a first attempt and known in its Repeat attempt) — baseline: unknown. Target: measured over the owner's first 10 quizzes; no fixed target (it informs §8 question 1).

## 8. Open questions

- [ ] Should a later Quiz start with the words whose saved result is repeat, now that results are saved? Carried from the small spec. Default now: no — a random sample, stored results are not read (AC-06). — owner: Maksym, due: any time; a change to the S-54 sample only.
- [ ] Should kind B of the choice builder show the stored definition's definition line (S-40) instead of the raw stored definition? It would change pick-the-answer's screen too (a visible change, rule 3). Default now: unchanged builder in both. — owner: Maksym, due: before pick-the-answer is next touched.
- [ ] Real gap sentences for words without a dialogue line need the owner's learn-kit deploy steps (the `vocab-learn-data` KV namespace, `0006_learn_allowance.sql`, deploy); until then those quizzes run choice-only with "Gap questions are unavailable" (AC-08). Default now: build and flip `available`; the web list needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.

## Implementation status

Implemented 2026-10-15 on `feat/learn-exercises`, test-first (commits `feat(learn-kit): ...` and `feat(learn-quiz): ...`). All 27 ACs have code and tests; no AC needed an Implementation note. §8 questions keep their defaults (random sample, stored results not read; pick-the-answer and the choice builder unchanged; the owner's learn-kit deploy steps are still needed for Worker gap sentences).

**Done.** Kit (S-55, S-56, additive, null defaults): `WordOutcome.detail` (the list tile's subtitle), `againLabel` / `onAgain` on `ResultSummary`, `ExerciseSummary` and `ExerciseScaffold` (the summary phase's values win, the scaffold's fill in; the button shows above "Done" only when both are known), and `examHeading(known, total)` in `result_summary.dart`. Exercise: `lib/features/learn/quiz/` (`Quiz` notifier family + `QuizState`, `QuizData`, `QuizQuestion`, `QuizAnswer`, pure `quizLayout`, `choiceLabel`, `typedLabel`; `QuizScreen`), `case 'quiz'` in `exerciseScreen`, `available: true` in `exercises.json` and `exercises.dart`. Unchanged: `question_builder.dart`, `choice_options.dart`, `gap_question.dart`, `typed_answer_field.dart`, `typed_match.dart`, `exam_result_sink.dart`, `word_result.dart`, the Worker code.

**The exam-result pattern as built (S-55), for the next exams.** In the notifier, every method that ends a question (`pick`, `submit`, `skip`) builds an answer and calls one private `_final(answer)`, which ignores a second final for the same question, stores the answer in the state, and in the same step calls `unawaited(ref.read(examResultSinkProvider).record(sessionId: sessionId, rowId: q.rowId, exerciseId: quizExerciseId, label: answer.label))`. `next`, `repeat`, the summary, Done and Back never record. Labels come from pure functions (`choiceLabel`, `typedLabel`; sentence exams use `examLabel` and record nothing for null). The summary is built from the stored answers: `examHeading`, "Known" / "Repeat", a `detail` line for repeat words, `againLabel` only when a word is repeat; the screen passes `onAgain: notifier.repeat` to `ExerciseScaffold`. Tests override `examResultSinkProvider` with a recording fake whose `record` never completes.

**Tests.** `learn_quiz_notifier_test` (28: layout, usable words, gap failure, determinism, every label, one record per final answer, none on Next / summary / leaving, the History id, summary details, Repeat), `learn_quiz_screen_test` (19: both question types under exam rules, no verdict before the summary, tap-to-Next in one frame with a never-completing save, Skip, summary, Repeat with no call or loading, gaps unavailable, not enough, History + Back), `learn_kit_widgets_test` (+4, S-56 and `examHeading`), `word_result_test` (+1, AC-22: a Quiz answer over the real store saves one result and moves neither session time, the word rows nor the Anki file), `learn_screen_test` (+1, AC-01), `exercise_route_test` (+1); AC-27 by a new case in `vocab-photo-api/test/learn.test.mjs`. Updated for the flip (`explain-to-friend` is now the unavailable example): `learn_screen_test`, `learn_exercises_test`, `exercise_route_test`, `learn.test.mjs`, `learn-exercises.test.mjs`.

**Notes.**
- Any throw from the gap load is caught (not only `LearnApiException`); a failure to read the words or dialogues still shows the frame's error line with Retry.
- The choice question's "Skip" is a right-aligned text button, the same as the exam field's.
- A Repeat attempt keys its fields and option widgets by attempt number, so nothing carries over from the earlier attempt.
- The Worker's web list shows the row as tickable and needs a deploy to match.
