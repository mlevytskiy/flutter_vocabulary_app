---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-15"
feature_size: "S"
---

# Spec — learn-fill-the-gaps

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-remember-or-not CONTEXT](../learn-remember-or-not/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/fill-the-gaps.md`](../learn-exercises/fill-the-gaps.md) (the clarified small spec — the starting point), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01, H-02, conflict notes 2, 4 and 7 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-03..D-08, D-12, D-13, D-18..D-20, D-22, D-41, S-01..S-42; this spec adds S-43..S-46), [`learn-exercises/quiz.md`](../learn-exercises/quiz.md) (the later user of the gap question), "Implementation status" of [`learn-kit/spec.md`](../learn-kit/spec.md) and [`learn-remember-or-not/spec.md`](../learn-remember-or-not/spec.md), kit code in `lib/features/learn/kit/` (`typed_answer_field.dart`, `typed_match.dart`, `word_marks.dart`, `example_line.dart`, `exercise_words.dart`), `lib/core/dialogues/dialogue_match.dart`, `lib/core/services/learn_api_service.dart` (kind `sentence`), `vocab-photo-api/src/learn/data.ts` and `prompts.ts` (kind `sentence`). House style: [`learn-match-definitions/spec.md`](../learn-match-definitions/spec.md).

## 1. Context

The learner has a word group selected on the learn page and wants to prove they can produce each word, not only recognise it. Fill the gaps is the first Step 2 exercise that asks for typing: one English sentence with the word replaced by "___", the word's translation under it as the cue, and the phone keyboard open. A right answer (or one small typo on a longer word) is right at once; a wrong one shows the first letter and the letter count and gives one more try; a second miss or "Show answer" shows the word. Each round ends with a summary of 1st try / 2nd try / missed.

Why now: `hard-decisions.md` Wave 1 lists it third, after the two match exercises, which are built. The kit already has every piece it needs but no user for them: the typed answer field and its matching rule (S-10, S-11), masking (S-12), the dialogue-line source (S-31) and the Worker's kind `sentence` (S-14, S-15). The Quiz (Stage 3) will ask the same gap questions in exam mode (D-41), so the way a gap question is made must be fixed once, here, as a kit contract.

Committed approach: one `@riverpod` notifier plus one round body on top of the kit (S-30). On open the notifier reads the group's words (`exerciseWordsProvider`, S-08) and the session's dialogues (`exerciseDialoguesProvider`, S-31). A new pure kit builder turns a word plus a text into a gap question (S-43); a kit loader takes a dialogue line first and asks the Worker for one sentence only for the words left without one, in one call (S-44). The round body shows the question through a small kit prompt widget and the kit's `TypedAnswerField` in practice mode, used unchanged (S-45). Results are summary-only (D-04, D-12).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- **Exact stored form in the gap (refines D-20, S-43).** The kit's match rule (`matchPlaces`) counts "walked" and "walks" as places of "walk", and the Worker's sentence check accepts them too. A gap hiding "walked" while the expected answer is "walk" would be unfair (D-18 makes "walked" wrong), so a gap sentence must hold the word exactly once (any other form of it anywhere also counts as a place and rejects the sentence) and that one place must be the stored form itself, in any letter case. Other sentences are rejected and the next source is tried. This is why the builder is not `exampleLineFor` (S-31 accepts any form, whole line).
- **One sentence, sensible length (S-43).** A dialogue line is cut into sentences and the first sentence that qualifies is the gap sentence; a leading dash is dropped. A sentence of fewer than 4 or more than 20 words (counting the gap as one), or of more than 160 characters, is rejected: "___!" teaches nothing, and a long line does not fit above the keyboard. The Worker sentence goes through the same check.
- **No Worker change.** The Worker's kind `sentence` is used as built (S-15: ≤120 characters, ≤15 words, the word once in any form). A Worker sentence with another form of the word leaves the word out. Changing the prompt would need a cache key bump (S-16) for every kind; it is done only if the KPI in §7 shows it is needed.
- **Translation required.** The cue is the translation (small spec), and the Worker's sense comes from it (D-06), so a word to learn with an empty translation is not usable and is never sent. The cue is masked with `maskWord` too (D-08), in case it holds the English word.
- **Error is all or nothing (D-05).** If every usable word has a dialogue gap sentence no call is made and the exercise works offline; if a call is needed and fails, the whole exercise shows the error frame, even though some words had dialogue lines. The Quiz will instead catch the same failure and go on with choice questions only (quiz.md); that is why the loader throws and leaves the reaction to its caller (S-44).
- **Kit copy kept.** The field's own lines stay as built: the hint "Starts with “w”, 4 letters" (the small spec's "w _ _ _" form would change the kit for the Quiz too, which shows no hint), "Almost: <word>", "Answer: <word>" and the "Show answer" button. Copy chosen here: title "Fill the gaps", counter "Question n of m" (m = round size, as pick-the-answer), instruction "Type the missing word", result lines "Right" (green) and "Missed" (red), button "Next", summary results "1st try" / "2nd try" / "Missed" and summary heading "Score: s of t" (2 / 1 / 0 points per word, D-12; t = 2 × round size). The not-enough line is the default one, as the small spec says.
- **No speaker.** The small spec says no TTS in v1; S-32 allows a speaker but does not require one, so none is added.
- **Order.** Group order inside each round, no shuffle (small spec); rounds of 3 to 9 (D-13). No `Random` is used.
- **Files:** `lib/features/learn/fill_the_gaps/` (`fill_the_gaps_notifier.dart`, `fill_the_gaps_screen.dart`, S-30), `lib/features/learn/kit/gap_question.dart` (S-43..S-45); `case 'fill-the-gaps'` in `exerciseScreen`; `available: true` in `exercises.json` (app and Worker) and `exercises.dart` (S-02). No change to `typed_answer_field.dart`, `typed_match.dart`, `word_marks.dart` or the Worker.

## 2. Goals

- The learner can practise producing every word of the selected group that has a translation and a fair sentence, by typing it into the gap.
- Checking is predictable and kind to phone typos, but asks for the exact stored word; feedback after every word says right, almost (with the spelling), or the answer.
- Every gap is fair: one gap per sentence, standing for exactly the stored form, the word visible nowhere else on screen.
- The gap question is a kit contract the Quiz can ask in exam mode without a second copy of the sentence rules.

## 3. Non-goals

- No saved results and no change to any word or dialogue (D-04, D-12); practice results are never a Step 3 result.
- No accepting other forms of the word ("walked" for "walk") and no AI judging of the answer (D-18): the exercise tests the stored word, offline.
- No multiple choice, no separate hint button and no speaker (small spec).
- No play on the shared page or the web learn page (D-11, H-07).
- No Worker prompt change and no kit field change in this feature (see §1).

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Fill the gaps in Step 2 and press Start with a word group selected
**So that** I practise exactly that group's words by typing them

### US-02: Type the missing word
**As a** learner
**I want** a sentence with one gap, the translation as a cue and the keyboard open at once
**So that** I recall and spell the word in context

### US-03: Fair checking with a second chance
**As a** learner
**I want** a small typo on a long word to count, a wrong answer to give me the first letter and length and one more try, and "Show answer" when I am stuck
**So that** a miss means I did not know the word, not that my thumb slipped

### US-04: Sentences from my own film dialogues
**As a** learner
**I want** a line from the film dialogue I collected the word from, and a short simple sentence only when there is none
**So that** I meet the word where I found it, at no AI cost

### US-05: Fair gaps
**As a** learner
**I want** each sentence to have exactly one gap that stands for the word as I stored it, with the word shown nowhere else
**So that** the answer is never given away and never a different form than I can type

### US-06: See my round results
**As a** learner
**I want** a summary after each round listing each word as 1st try, 2nd try or missed, with my score
**So that** I know which words to look at again

### US-07: Clear stop when the group cannot be practised
**As a** learner
**I want** a plain message when the group has too few words with sentences or the sentences cannot be loaded
**So that** I am never left on an empty or broken round

### US-08: Practise any session without changing it
**As a** learner
**I want** to practise a group of the current session or of a History session
**So that** old sessions are useful too, and practising never changes my words

### US-09: The same gap questions in the Quiz
**As a** learner
**I want** the Quiz's gap questions to be built by the same rules as this exercise
**So that** a word I practised here is asked the same fair way in the exam

## 5. Acceptance criteria

### Opening and the question

### AC-01 (US-01) — happy path
**Given** the app after this feature and a selected word group of 5 words to learn, each with a translation and a linked film dialogue line that holds it once in its stored form
**When** the learner opens the learn page, ticks "Fill the gaps" in Step 2 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens with the title "Fill the gaps" and shows "Question 1 of 5", "Type the missing word", the first word's sentence with "___" in place of the word, and the word's translation under it; the keyboard is open without a tap, with no autocorrect and no suggestions; the Worker is not asked.

### AC-02 (US-05) — domain invariant
**Given** any question of the exercise, including one for the phrase "give up"
**When** it shows, before the answer is final
**Then** the sentence holds exactly one "___" (one for the whole phrase), and neither the sentence nor the cue shows the word in any letter case or form; a cue that holds the English word shows "___" there.

### Answering

### AC-03 (US-03) — happy path
**Given** the question for "received"
**When** the learner types "Received " (capital letter, trailing space) and presses Send
**Then** "Right" shows in green, the full sentence shows with "received" in bold in place of the gap, the field becomes read-only, "Show answer" disappears and "Next" shows; the word's result is "1st try".

### AC-04 (US-03) — happy path
**Given** the question for "receive"
**When** the learner types "recieve" and presses Send
**Then** it counts as right on this try: "Right" and "Almost: receive" show with the full sentence and "Next"; the result is "1st try".

### AC-05 (US-03) — domain invariant
**Given** the question for "cat"
**When** the learner types "cot" and presses Send
**Then** it is wrong (a one-letter slip counts only on words of 5 or more letters) and the hint and second try of AC-06 follow.

### AC-06 (US-03) — error
**Given** the question for "walk", on the first try
**When** the learner types "walked" (another form of the word) and presses Send
**Then** it is wrong: "Starts with “w”, 4 letters" shows under the field, the typed text stays for editing, the keyboard stays open, and the learner may send once more.

### AC-07 (US-03) — happy path
**Given** a question with one wrong try sent
**When** the learner sends the right word (or one slip of it on a word of 5+ letters)
**Then** "Right" shows with the full sentence and "Next"; the word's result is "2nd try".

### AC-08 (US-03) — error
**Given** the question for "walk" with one wrong try sent
**When** the learner sends a second wrong answer
**Then** "Missed" shows in red with "Answer: walk" and the full sentence with the word in bold; the field is read-only and "Next" shows; the result is "Missed".

### AC-09 (US-03) — happy path
**Given** a question before any try, or after one wrong try
**When** the learner taps "Show answer"
**Then** the word ends as "Missed" exactly as in AC-08, without a try being counted.

### AC-10 (US-02) — error
**Given** a question with an empty field or only spaces in it
**When** the learner presses Send
**Then** nothing happens: no try is counted, no hint shows, the keyboard stays open.

### AC-11 (US-03) — domain invariant
**Given** a question whose answer is final (right, almost, missed or shown)
**When** the learner tries to type or press Send again
**Then** nothing changes: the result stays, and only "Next" moves on.

### AC-12 (US-03) — domain invariant
**Given** the stored word "give up" and the stored word "the shore"
**When** the learner types "to give up" and "shore"
**Then** both are right (a leading "to", "a", "an" or "the" is ignored on both sides, extra inner spaces are ignored); the first-try hint for "give up" would read "Starts with “g”, 6 letters" (spaces not counted).

### AC-13 (US-02) — happy path
**Given** a final answer on question 3 of 5
**When** the learner taps "Next"
**Then** "Question 4 of 5" shows with an empty field and the keyboard open; after the last question of the round "Next" opens the round summary.

### Where the sentence comes from

### AC-14 (US-04) — cross-context
**Given** a word "harbour" linked to a visible film dialogue of the same session whose second line holds "harbour" once, and a Worker that would also give a sentence
**When** the exercise opens
**Then** the question uses that dialogue line, and the Worker is not asked about "harbour".

### AC-15 (US-04) — cross-context
**Given** a group of 6 words of which 2 have no qualifying dialogue line
**When** the exercise opens
**Then** the Worker is asked once, for those 2 words only, with their translations; the other 4 use their dialogue lines; when all 6 have dialogue lines the Worker is not asked at all and the exercise works with the phone offline.

### AC-16 (US-05) — domain invariant
**Given** a dialogue line "- Wait. The harbour is closed tonight. Go home."
**When** it is the gap sentence for "harbour"
**Then** the question shows only "The ___ is closed tonight." (the line is cut to its one sentence around the word, the leading dash dropped).

### AC-17 (US-05) — domain invariant
**Given** for "walk" the linked lines "I walk, you walk." (twice), "She walks to work every day." (another form only) and "Let's walk to the station now."
**When** the gap sentence is chosen
**Then** the first two are rejected and the third is used; if no line qualified, the Worker sentence would be tried, and a Worker sentence that holds "walked" instead of "walk" leaves the word out.

### AC-18 (US-05) — domain invariant
**Given** for "received" a linked line "Received!" and a linked line longer than 160 characters with no sentence end
**When** the gap sentence is chosen
**Then** both are rejected (a gap sentence has 4 to 20 words counting the gap as one, and at most 160 characters), and the next source is tried.

### AC-19 (US-04) — domain invariant
**Given** a hidden dialogue, a dialogue not linked to the word, and a dialogue of another session that each hold the word
**When** the gap sentence is chosen
**Then** none of them is used.

### AC-20 (US-05) — domain invariant
**Given** a word for which the Worker answers "none", and a word to learn with a definition but an empty translation
**When** the exercise opens
**Then** both are left out (not asked, not in the summary); the word without a translation is never sent to the Worker.

### Rounds, empty and error states

### AC-21 (US-06) — domain invariant
**Given** a group of 12 usable words
**When** the exercise opens
**Then** it runs two rounds of 6 in group order; 19 give 7 + 6 + 6, 9 give one round, 3 give one round (rounds of 3 to 9, never under 3); questions within a round keep group order.

### AC-22 (US-07) — error
**Given** a selected group with fewer than 3 words to learn (including one whose words were all deleted)
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked.

### AC-23 (US-07) — error
**Given** a selected group with 3 or more words to learn of which fewer than 3 are usable once the sentences are gathered
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, no question appears, and Back returns to the learn page.

### AC-24 (US-07) — error
**Given** the phone is offline (or the Worker fails, times out or has no exercise storage) and at least one usable word has no dialogue gap sentence
**When** the exercise opens
**Then** only "Could not load the exercise. Check the connection and try again." and "Retry" show, no question appears, even if other words have dialogue lines; back online, Retry loads the sentences and question 1 shows.

### AC-25 (US-07) — cross-context
**Given** the Worker's daily exercise allowance is used up and a needed sentence is not in its cache
**When** the exercise opens
**Then** only "Today's exercise limit is reached. Try again tomorrow." and "Back" show; when the Worker answers that requests are too frequent, "Too many requests. Wait a moment and try again." and "Retry" show instead.

### Summary, sessions and people

### AC-26 (US-06) — happy path
**Given** a round of 5 words answered 1st try, 1st try, 2nd try, missed by "Show answer", and 1st try with an almost
**When** the summary opens
**Then** it shows "Score: 7 of 10" above the list and lists the words in group order as "1st try", "1st try", "2nd try", "Missed", "1st try"; "Next round" while rounds remain, "Done" after the last; Done returns to the learn page (or opens the next ticked exercise, as today).

### AC-27 (US-08) — domain invariant
**Given** a round in progress (Back mid-question) or finished
**When** the learner leaves
**Then** nothing is kept: no word result, no change to any word, translation, definition, group or dialogue; opening again starts at question 1 of round 1.

### AC-28 (US-08) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner plays the exercise to the end
**Then** only that session's words and dialogues are used, only that group's words without a dialogue gap sentence are sent to the Worker (with their translations), and the History session is unchanged afterwards (same words, groups, dialogues and last-changed time).

### AC-29 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 2
**Then** Fill the gaps is listed with the same name and step as in the app and cannot be played there; only the learner, in the app, can play it (the Worker's exercise data is behind the app's secret).

### AC-30 (US-09) — cross-context
**Given** the same words, dialogues and Worker answers
**When** the gap questions are built twice, or later by the Quiz
**Then** each word gets the same sentence, gap, cue and expected answer every time, whatever the mode; nothing in a gap question is practice-only, so in exam mode the same question shows with no hint, no second try and no "Show answer" (only Skip), and the full sentence is never shown before the answer is final.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per Retry) | 0 when every usable word has a dialogue gap sentence or the group has under 3 words to learn; else exactly 1, holding only the words without one; 0 during questions, Next, Next round and summary | widget test with a counting `learnApiService` fake |
| Day-cap cost of a repeat open | 0 units (all cache hits) | existing Worker test (all-hit request takes none, S-18) |
| Start to first question, release build, mid-range Android phone | ≤ 1.0 s with all dialogue sentences; ≤ 1.5 s for a cached group on a good network | manual check before ship |
| Start to error line when the Worker does not answer | ≤ 31 s (app timeout 30 s, S-13) | unit test with a short `dataTimeout` |
| Send to feedback | ≤ 100 ms (no network, no AI) | widget test pumps one frame |
| Determinism | same words + dialogues + Worker answers → same usable words, rounds and gap questions, 100% | unit tests of the S-43/S-44 builder and loader |
| Fairness | 0 gap questions with more or fewer than one "___", with the word (any form, any case) visible in sentence or cue, or whose hidden text is not the stored form, on a fixture of twice-holding, inflected, multi-sentence, short, long and phrase lines | unit tests of `gapFromText` |
| Kit reuse | 0 changed lines in `typed_answer_field.dart`, `typed_match.dart`, `word_marks.dart`, `example_line.dart` | `git diff` at `sdd:review` |
| Test coverage | every AC has a unit or widget test; AC-29 by the Worker learn-page test | `tool/test.sh changed` |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, translations and film dialogue lines.
- **Personal data touched:** none new. Only words without a dialogue gap sentence go to the Worker (word, translation, row id), as the other kinds already do; dialogue lines and typed answers never leave the phone for this exercise.
- **AuthZ/AuthN impact:** none new. The exercise data route is behind the app's secret (S-14); no play surface on the web.
- **Abuse cases:**
  - Partner tries to play from a web link: the web learn page lists the exercise only (AC-29).
  - Repeated opens draining the AI budget: dialogue lines take no call; cache hits take nothing; misses take one unit per call against the daily cap (AC-25, S-18).
  - AI or dialogue text with markup or great length: shown as plain text, cut to one sentence, rejected over 160 characters (AC-16, AC-18); the Worker caps a sentence at 120 characters.
  - A sentence giving the word away or hiding another form: rejected (AC-02, AC-17).
- **Security review:** N/A — no new data flow, route, secret or storage.

## 7. Metrics / KPIs

The app has no usage analytics; checked at review, from the Worker's `learn data` log lines (S-24) and the owner's own use.

- **Groups that can be practised** (owner's groups showing a question, not "Not enough words…") — baseline: 0 (not available). Target: at least 8 of 10 within 14 days of ship.
- **Worker sentences left out for the word's form** (non-null Worker sentences rejected by S-43, over all Worker sentences) — baseline: unknown, measured in a debug run on the owner's sessions. Target: ≤ 20%; above that, a follow-up asks the Worker for the exact form and bumps the cache key (S-16).
- **Words served without an AI call** (dialogue sentences + cache hits, over all questions shown) — baseline: 0. Target: ≥ 60% in the first 30 days after deploy.
- **Unfair gaps reported by the owner** (word visible, wrong form hidden, two gaps) — baseline: n/a. Target: 0 in the first 30 days.

## 8. Open questions

- [ ] Should an "almost" (one typo) score less than a perfect answer? Carried from the small spec. Default now: no, equal (counts as right and as its try, AC-04, AC-26). — owner: Maksym, due: any time; a change to the score mapping only.
- [ ] Real use for words without a dialogue gap sentence needs the owner's learn-kit deploy steps (the `vocab-learn-data` KV namespace, `0006_learn_allowance.sql`, deploy); until then those groups show the error line (AC-24), groups whose words all have dialogue lines already work. Default now: build and flip `available`; the web list needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.
