---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-15"
feature_size: "S"
---

# Spec — learn-sentence-patterns

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-fill-the-gaps CONTEXT](../learn-fill-the-gaps/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/sentence-patterns.md`](../learn-exercises/sentence-patterns.md) (the clarified small spec — the starting point) and its screenshot [`ai-chat-sentence-patterns.jpeg`](../learn-exercises/screenshots/ai-chat-sentence-patterns.jpeg), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01..H-04, Wave 2 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-03..D-06, D-12, D-13, D-19, D-22, D-24..D-27, D-32, D-34, D-40, S-01..S-46; this spec adds S-47..S-50), the Stage 3 small specs that will reuse the check ([`own-sentences.md`](../learn-exercises/own-sentences.md), [`translate-sentences.md`](../learn-exercises/translate-sentences.md), [`explain-to-friend.md`](../learn-exercises/explain-to-friend.md)), "Implementation status" of [`learn-kit/spec.md`](../learn-kit/spec.md) and [`learn-fill-the-gaps/spec.md`](../learn-fill-the-gaps/spec.md), kit code in `lib/features/learn/kit/` (`check_verdict.dart`, `check_result_line.dart`, `typed_answer_field.dart`, `word_marks.dart`, `exercise_phase.dart`, `result_summary.dart`), `lib/features/learn/fill_the_gaps/`, `lib/core/services/learn_api_service.dart` (`check`, kind `pattern`), `lib/features/word_input/widgets/pronunciation_buttons.dart`, `vocab-photo-api/src/learn/check.ts`, `data.ts` and `prompts.ts` (kind `pattern`, the check prompt). House style: [`learn-fill-the-gaps/spec.md`](../learn-fill-the-gaps/spec.md).

## 1. Context

The learner has a word group selected on the learn page and wants to start producing its words in sentences, but a blank page is hard. Sentence patterns gives a frame: for each word a good English sentence with the word in bold, the reusable pattern behind it ("Pattern: The main + [noun] + was that + [sentence]") and a line saying when to use it ("Use it to: …"), with a speaker. The learner taps "My turn", writes their own sentence with the same word and pattern, and the AI checks it: "Good", or one corrected sentence and a short note. One send per word; Skip is always possible. The round ends with a summary of right, fixed and skipped words.

Why now: `hard-decisions.md` Wave 2 puts sentence-patterns first because it is the first user of the sentence check (H-03, H-04, S-20, S-21) and of the Worker's kind `pattern` (S-15). Both exist on the Worker and in the app service but have no screen yet. Three Stage 3 exams (own-sentences, translate-sentences, explain-to-friend) send the same kind of check, so how a sentence is typed, pre-checked, sent, retried, judged and shown has to be fixed once, here, as a kit contract. A practice exercise with a scaffold is the safe place to prove it before exams depend on it.

Committed approach: one `@riverpod` notifier plus one round body on top of the kit (S-30). On open the notifier reads the group's words (`exerciseWordsProvider`, S-08) and asks the Worker once for kind `pattern` for the words to learn that have a translation. The round body shows a pattern card and, after "My turn", a new kit widget, `SentenceCheckField`, in practice mode (S-47). The field owns the typing, the pre-check, the call, the spinner, the error line with Retry and the result line; it reports one final `SentenceResult` per word, which the notifier keeps for the summary. The mapping from that result to practice labels and to exam results is a pure kit function (S-48). Results are summary-only (D-04, D-12).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- **The check UI is a kit widget, not this exercise's (S-47).** `TypedAnswerField` (S-11) is built for one expected word (`matchTyped`, first-letter hint, second try) and cannot judge a sentence, so it is not reused. `SentenceCheckField` is new in the kit and is used by four exercises; nothing in it is pattern-only (the pattern text travels as the check's `extra`). The call is made from the widget's `State` through `learnApiServiceProvider`, because the in-flight flag and the error are widget state (CLAUDE.md rule 2); the notifier only receives the final result, as fill-the-gaps receives `TypedAnswerResult`.
- **Practice versus exam (S-47).** Both modes allow one checked sentence per word and Skip until the word is final. They differ in two places only: after a failed check, practice unlocks the text (the learner may edit, Retry sends the current text after the pre-check) while an exam keeps the sent text locked and Retry resends exactly it (D-34, D-25); and the labels and results of S-48. The result line (Good / fixed + note) shows at once in both modes, as the three exam small specs ask. A countdown (explain-to-friend, D-40) is not in the contract: S-05 forbids kit parts with one user, so explain-to-friend adds it to the kit when it is specified.
- **Four outcomes (S-48).** `right`, `fixed`, `skipped` (Skip before any check was sent) and `notChecked` (Skip after a sent check failed and was not retried to an answer). Practice shows `skipped` and `notChecked` both as "Skipped" (small spec: "a failed check that is never retried counts as skipped"); an exam maps `notChecked` to no result (D-32: error = no result) and `skipped` to repeat.
- **The fixed sentence shows the word in bold (S-49, D-27).** The kit's `CheckResultLine` gets an optional `word`; with it, the fixed sentence is shown through `boldWord`. Without it nothing changes.
- **Data from the Worker only.** The Worker's kind `pattern` is used as built (S-15: sentence ≤120 characters and ≤15 words holding the word once; pattern ≤60 characters with only the five slots and without the word; usage ≤60). Dialogue lines are not used (they have no pattern, small spec). No prompt change, so no cache key bump (S-16). The app keeps only words whose sentence holds the word once by its own rule (`holdsWordOnce`, the same rule as the Worker), so bolding always has exactly one place.
- **Translation required (S-50).** The Worker's sense and the check's sense come from the translation (D-06), and the card shows it, so a word to learn with an empty translation is not usable and is never sent. Fewer than 3 such words shows "Not enough words" without a call; otherwise one data call for all of them; a null answer leaves the word out. translate-sentences loads its kind `translate` by the same rule.
- **The speaker reads the sentence.** The small spec says the speaker reads the sentence; the app's US / UK pronunciation buttons are reused unchanged (S-32), and their tap speaks the card's sentence instead of the word (the buttons leave the text to the caller). Shown from the start: the word is never hidden in this exercise.
- **Copy chosen here:** title "Sentence patterns", counter "Word n of m" (m = round size), "Pattern: <pattern>", "Use it to: <usage>", button "My turn", prompt "Write your own sentence with “<word>” and this pattern.", spinner line "Checking…", buttons "Skip" and "Next", summary results "Right" / "Fixed" / "Skipped", summary heading none (small spec: labels only; §8). The kit's lines stay: "Write a full sentence", "Keep it under two hundred characters", "Good", "Could not check the sentence. Check the connection and try again.", the frame's day-limit and rate-limit lines.
- **Order and rounds.** Group order, no shuffle, no `Random`; rounds of 3 to 9 (D-13, `splitRounds`).
- **Files:** `lib/features/learn/sentence_patterns/` (`sentence_patterns_notifier.dart`, `sentence_patterns_screen.dart`, S-30), `lib/features/learn/kit/sentence_check.dart` (S-47, S-48); `check_result_line.dart` gets the optional `word` (S-49); `case 'sentence-patterns'` in `exerciseScreen`; `available: true` in `exercises.json` (Worker) and `exercises.dart` (S-02). No Worker code change; `judgeCheck`, `sentenceProblem`, `TypedAnswerField` and `word_marks.dart` are unchanged.

## 2. Goals

- The learner can turn every word of the selected group that has a translation into a sentence of their own, with a model sentence and a pattern as the scaffold.
- Every sent sentence gets a fair, fast verdict: "Good", or one corrected sentence with a short note; a network problem never loses the typed text and never counts as an answer.
- The sentence check and its feedback are a kit contract the three Stage 3 sentence exams use unchanged, so exams and practice judge sentences by the same rule.

## 3. Non-goals

- No saved results and no change to any word (D-04, D-12); practice results are never a Step 3 result (no `ExamResultSink` write).
- No second try after a checked sentence and no free chat with the AI: one check per word (small spec, D-26).
- No dialogue lines as model sentences and no pattern-only reading mode (small spec).
- No play on the shared page or the web learn page (D-11, H-07).
- No Worker change, no countdown in the kit, no change to `TypedAnswerField` (see §1).

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Sentence patterns in Step 2 and press Start with a word group selected
**So that** I practise exactly that group's words in sentences

### US-02: Study the model sentence and its pattern
**As a** learner
**I want** each word in a natural sentence with the word in bold, the pattern with its slots, when to use it, the translation, and a speaker
**So that** I have a frame to copy before I write

### US-03: Write my own sentence and get it checked
**As a** learner
**I want** to tap "My turn", type a sentence with the word and the pattern, and get "Good" or a corrected sentence with a short note
**So that** I learn to use the word correctly in a frame I can reuse

### US-04: Never lose my sentence to a network problem
**As a** learner
**I want** my typed sentence kept and a Retry when the check cannot be made
**So that** a bad connection costs me nothing

### US-05: See my round results
**As a** learner
**I want** a summary after each round listing each word as right, fixed or skipped
**So that** I know which words need more practice

### US-06: Clear stop when the group cannot be practised
**As a** learner
**I want** a plain message when the group has too few words with patterns or the patterns cannot be loaded
**So that** I am never left on an empty or broken round

### US-07: Practise any session without changing it
**As a** learner
**I want** to practise a group of the current session or of a History session
**So that** old sessions are useful too, and practising never changes my words

### US-08: The same check in the exams
**As a** learner
**I want** my sentences in the Step 3 exams to be typed, checked and shown the same way as here
**So that** a sentence judged "Good" in practice would be judged the same in the exam

## 5. Acceptance criteria

### Opening and the card

### AC-01 (US-01) — happy path
**Given** the app after this feature and a selected word group of 5 words to learn, each with a translation, and a Worker that has a pattern for each
**When** the learner opens the learn page, ticks "Sentence patterns" in Step 2 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens with the title "Sentence patterns" and shows "Word 1 of 5", the first word's model sentence, a line "Pattern: …", a line "Use it to: …", the word's translation in small text under the card, the speaker buttons and a "My turn" button; no text field and no keyboard yet.

### AC-02 (US-02) — domain invariant
**Given** the model sentence "The main conflict was that two teams wanted different things." for "conflict", and for "walk" a sentence holding "walked"
**When** the card shows
**Then** "conflict" (and "walked") is bold and every other word is plain; the sentence shows as plain text even if it holds stars or other markup characters.

### AC-03 (US-02) — domain invariant
**Given** any card
**When** it shows
**Then** the pattern line holds at least one slot in square brackets, only from "[noun]", "[verb]", "[adjective]", "[sentence]" and "[verb in Past Simple]", and does not spell the word in any form; the usage line is at most 60 characters.

### AC-04 (US-02) — happy path
**Given** a card
**When** the learner taps the US or the UK speaker
**Then** the model sentence is read aloud in that accent; a second tap interrupts it; moving to the next word or leaving stops it; a speech error shows its message briefly and changes nothing else.

### Writing and the check

### AC-05 (US-03) — happy path
**Given** a card before "My turn"
**When** the learner taps "My turn"
**Then** the card stays on top, the prompt "Write your own sentence with “conflict” and this pattern." shows, a text field below it opens with the keyboard (no autocorrect, no suggestions), the keyboard's action key is Send, and "Skip" shows; "My turn" disappears.

### AC-06 (US-03) — error
**Given** the field holds nothing, only spaces, or one word ("conflict")
**When** the learner presses Send
**Then** nothing is sent, "Write a full sentence" shows under the field, the text stays and the keyboard stays open; a text over two hundred characters shows "Keep it under two hundred characters" instead, also without sending.

### AC-07 (US-03) — happy path
**Given** the pattern "The main + [noun] + was that + [sentence]" for "conflict"
**When** the learner sends "The main conflict was that nobody had time." and the check finds no error and the pattern used
**Then** "Checking…" with a spinner shows at once and Send and Skip do nothing meanwhile; then "Good" shows under the read-only sentence, "Skip" disappears and "Next" shows; the word's result is "Right".

### AC-08 (US-03) — happy path
**Given** the same card
**When** the learner sends "The main conflict were that nobody have time." (grammar errors) or "We had a conflict yesterday." (no pattern)
**Then** one corrected sentence shows with "conflict" in bold, and one note of at most 100 characters under it; the sentence is read-only, "Next" shows; the word's result is "Fixed".

### AC-09 (US-03) — domain invariant
**Given** the word "walk" with the pattern "In the end, + we + [verb in Past Simple]"
**When** the learner sends a correct sentence that holds "walked"
**Then** the word counts as used (any inflected form), and the result is decided by the pattern and the grammar only.

### AC-10 (US-03) — domain invariant
**Given** the AI judges a sentence correct but the sentence holds a synonym instead of the word ("dispute" for "conflict")
**When** the result is decided
**Then** the result is "Fixed" and the note reads "Use “conflict” in your sentence."; and when the AI calls a sentence wrong but its corrected sentence equals the learner's (ignoring case, outer spaces and end punctuation), the result is "Good".

### AC-11 (US-03) — domain invariant
**Given** a word whose sentence was checked ("Good" or fixed)
**When** the learner tries to edit the sentence or press Send again
**Then** nothing changes and no second check is sent; only "Next" moves on.

### AC-12 (US-03) — happy path
**Given** a card after "My turn", with or without text typed and nothing sent
**When** the learner taps "Skip"
**Then** no check is sent, "Skipped" shows, the field is read-only and "Next" shows; the word's result is "Skipped". (Before "My turn" there is no Skip: the card is read first.)

### AC-13 (US-03) — happy path
**Given** a final word on word 3 of 5
**When** the learner taps "Next"
**Then** word 4's card shows with "My turn" and no field; after the last word of the round "Next" opens the round summary.

### Check failures

### AC-14 (US-04) — error
**Given** the phone is offline, the server fails, or the check does not answer within 15 seconds
**When** the learner sends a valid sentence
**Then** "Could not check the sentence. Check the connection and try again." and "Retry" show, the typed sentence stays in the field, no result line shows and no answer is counted.

### AC-15 (US-04) — happy path
**Given** a failed check (AC-14)
**When** the learner edits the sentence or not, and taps "Retry" (or presses Send)
**Then** the current text is pre-checked as in AC-06 and, if valid, sent once more with the spinner; a verdict then shows as in AC-07 or AC-08 and the word ends with that result; the earlier failure is not a try.

### AC-16 (US-04) — error
**Given** a failed check that the learner does not retry
**When** the learner taps "Skip"
**Then** the word ends as "Skipped" (shown as "Skipped" and in the summary) and no further check is sent.

### AC-17 (US-04) — cross-context
**Given** the app's daily allowance of sentence checks is used up
**When** the learner sends a valid sentence
**Then** "Today's exercise limit is reached. Try again tomorrow." shows with no Retry, the text stays, and "Skip" still ends the word as "Skipped"; when instead the server answers that requests are too frequent, "Too many requests. Wait a moment and try again." and "Retry" show.

### AC-18 (US-04) — domain invariant
**Given** a check in flight
**When** the learner leaves the exercise with Back before the answer
**Then** the late answer changes nothing and causes no error; nothing is kept; reopening starts at word 1 of round 1.

### Where the data comes from

### AC-19 (US-02) — cross-context
**Given** a group of 6 words to learn with translations
**When** the exercise opens
**Then** the Worker is asked once for the patterns of exactly those 6 words, each with its translation, while the frame's loading state shows; no sentence check is sent until the learner sends a sentence; the same group opened again within 30 days takes nothing from the daily data allowance.

### AC-20 (US-06) — domain invariant
**Given** a word for which the Worker answers "none" (or an answer that breaks the sentence, pattern or usage rule), and a word to learn with a definition but an empty translation
**When** the exercise opens
**Then** both are left out (no card, not in the summary); the word without a translation is never sent to the Worker.

### Rounds, empty and error states

### AC-21 (US-05) — domain invariant
**Given** a group of 12 usable words
**When** the exercise opens
**Then** it runs two rounds of 6 in group order; 19 give 7 + 6 + 6, 9 give one round, 3 give one round (rounds of 3 to 9, never under 3); cards within a round keep group order.

### AC-22 (US-06) — error
**Given** a selected group with fewer than 3 words to learn that have a translation
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked.

### AC-23 (US-06) — error
**Given** a selected group with 3 or more words to learn, of which fewer than 3 get a usable pattern
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, and Back returns to the learn page.

### AC-24 (US-06) — error
**Given** the phone is offline (or the Worker fails, times out or has no exercise storage) while the patterns load
**When** the exercise opens
**Then** only "Could not load the exercise. Check the connection and try again." and "Retry" show; back online, Retry loads the patterns and word 1 shows.

### AC-25 (US-06) — cross-context
**Given** the Worker's daily allowance for exercise data is used up and a needed pattern is not in its cache
**When** the exercise opens
**Then** only "Today's exercise limit is reached. Try again tomorrow." and "Back" show; when the Worker answers that requests are too frequent, "Too many requests. Wait a moment and try again." and "Retry" show instead.

### Summary, sessions and people

### AC-26 (US-05) — happy path
**Given** a round of 5 words ended as Good, fixed, skipped before sending, skipped after a failed check, and Good after one Retry
**When** the summary opens
**Then** it lists the words in group order as "Right", "Fixed", "Skipped", "Skipped", "Right", with no heading; "Next round" while rounds remain, "Done" after the last; Done returns to the learn page (or opens the next ticked exercise, as today).

### AC-27 (US-07) — domain invariant
**Given** a round in progress or finished
**When** the learner leaves
**Then** nothing is kept: no word result, no change to any word, translation, definition, group or session; the learner's sentences are not stored anywhere.

### AC-28 (US-07) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner plays the exercise to the end
**Then** only that session's words are used and sent (with their translations), and the History session is unchanged afterwards (same words, groups and last-changed time).

### AC-29 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 2
**Then** Sentence patterns is listed with the same name and step as in the app and cannot be played there; only the learner, in the app, can play it (the Worker's exercise data and sentence check are behind the app's secret).

### The kit contract for the exams

### AC-30 (US-08) — cross-context
**Given** the shared sentence field in exam mode, as own-sentences, translate-sentences and explain-to-friend will use it
**When** a sent sentence's check fails
**Then** the sent text stays locked (it cannot be edited), "Retry" resends exactly that text, and a retry is not a second try; everything else (pre-check lines, spinner, one check per word, Skip until the word is final, the result line) behaves as in AC-06..AC-17.

### AC-31 (US-08) — domain invariant
**Given** the four ways a word can end (Good, fixed, Skip before any check, Skip after a failed check)
**When** they are shown or recorded
**Then** practice shows "Right", "Fixed", "Skipped", "Skipped" and records nothing; an exam records known, repeat, repeat and no result, and the same sentence with the same check answer gets the same verdict in both modes.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per load Retry) | 0 when the group has fewer than 3 words to learn with a translation; else exactly 1 data call holding only those words; 0 checks on open | widget test with a counting `learnApiService` fake |
| Checks per word | exactly 1 per valid Send or check Retry; 0 for an invalid text, "My turn", Skip, Next, Next round and the summary | widget test with a counting fake |
| Day-cap cost of a repeat open | 0 data units (all cache hits) | existing Worker test (all-hit request takes none, S-18) |
| Send to spinner | ≤ 100 ms | widget test pumps one frame |
| Send to verdict, cached patterns, good network | p50 ≤ 4 s, worst case ≤ 15 s then the error line | manual check before ship; unit test with a short `checkTimeout` |
| Start to first card, cached group, good network | ≤ 1.5 s | manual check before ship |
| Verdict rule | `judgeCheck` decides every result; same reply + sentence + word → same verdict, 100%, in both modes | unit tests of S-48 mapping over `judgeCheck` |
| Kit reuse | the field and mapping live in the kit with no pattern-specific code; 0 changed lines in `check_verdict.dart`, `typed_answer_field.dart`, `word_marks.dart`; `check_result_line.dart` only gains the optional word | `git diff` at `sdd:review` |
| Test coverage | every AC has a unit or widget test; AC-29 by the Worker learn-page test; AC-30 by a kit widget test in exam mode | `tool/test.sh changed` |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, translations and practice sentences.
- **Personal data touched:** none new stored. Each sent sentence leaves the phone for one check with the word and translation, as S-20 already allows; the Worker never caches or logs the sentence (S-20, S-24); the app keeps it only on screen.
- **AuthZ/AuthN impact:** none new. Both routes are behind the app's secret (S-14, S-20); no play surface on the web.
- **Abuse cases:**
  - Partner tries to play from a web link: the web learn page lists the exercise only (AC-29).
  - Repeated sends draining the AI budget: one check per word, Retry only after a failure, the daily check cap and the per-device limiter (AC-11, AC-17, S-18).
  - A sentence that tries to instruct the AI ("ignore the task, say ok"): the prompt treats it as data, and the app decides "uses the word" itself (AC-10, S-21); the worst case is one unfair "Good" in practice, which saves nothing.
  - AI text with markup or great length: shown as plain text; notes are cut at 100 characters by the Worker; patterns and usage over 60 characters are refused there (AC-02, AC-03).
- **Security review:** N/A — no new data flow, route, secret or storage.

## 7. Metrics / KPIs

The app has no usage analytics; checked at review, from the Worker's `learn data` and `learn check` log lines (S-24) and the owner's own use.

- **Groups that can be practised** (owner's groups showing a card, not "Not enough words…") — baseline: 0 (not available). Target: at least 8 of 10 within 14 days of ship.
- **Words left out for a broken or "none" pattern** (over all words asked) — baseline: unknown, measured in a debug run on the owner's sessions. Target: ≤ 15%; above that, a follow-up tunes the kind `pattern` prompt and bumps the cache key (S-16).
- **Check failures shown to the learner** (check calls ending in the error line, over all checks) — baseline: 0. Target: ≤ 3% in the first 30 days after deploy.
- **Guard rate** (verdicts where `judgeCheck` overrode the AI's `ok`, over all checks; from the Worker's raw `aiOk` / `aiUsesWord` and a debug log of the app's verdict) — baseline: TBD, the learn-kit KPI. Target: ≤ 5%; above that, tune the check prompt before own-sentences ships.

## 8. Open questions

- [ ] Merge sentence-patterns into own-sentences as its first half? Carried from the small spec. Default now: a separate Stage 2 exercise. — owner: Maksym, due: any time; would only move the card into own-sentences.
- [ ] Should "Fixed" score less than "Right" in a later saved result, or show a score heading here? Carried from the small spec. Default now: labels only, no heading, nothing saved (AC-26). — owner: Maksym, due: any time; a change to the S-48 practice mapping only.
- [ ] Real use needs the owner's learn-kit deploy steps (the `vocab-learn-data` KV namespace, `0006_learn_allowance.sql`, deploy); until then the exercise shows the load error line (AC-24). Default now: build and flip `available`; the web list needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.
