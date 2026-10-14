---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-15"
feature_size: "S"
---

# Spec — learn-translate-sentences

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-sentence-patterns CONTEXT](../learn-sentence-patterns/CONTEXT.md) · [learn-quiz CONTEXT](../learn-quiz/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/translate-sentences.md`](../learn-exercises/translate-sentences.md) (the clarified small spec — the starting point), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-02..H-06, Wave 3 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-05, D-06, D-08, D-13, D-24..D-27, D-31..D-41, S-06, S-08, S-12..S-24, S-27, S-30, S-34, S-47..S-50, S-55, S-56; this spec adds S-57, S-58), "Implementation status" of [`learn-sentence-patterns/spec.md`](../learn-sentence-patterns/spec.md) (the built `SentenceCheckField`) and [`learn-quiz/spec.md`](../learn-quiz/spec.md) (the exam-result pattern as built), kit code in `lib/features/learn/kit/` (`sentence_check.dart`, `check_verdict.dart` (`judgeCheck`, `sentenceProblem`), `check_result_line.dart`, `result_summary.dart` (`WordOutcome.detail`, `examHeading`), `exercise_phase.dart`, `exercise_scaffold.dart`, `split_rounds.dart`, `exercise_random.dart`, `word_marks.dart`), `lib/core/services/learn_api_service.dart` (`LearnDataKind.translate` → `TranslateData (source, cue, model)`, `LearnCheckTask.translate`), `lib/features/learn/quiz/quiz_notifier.dart`, `lib/features/learn/sentence_patterns/`, Worker `vocab-photo-api/src/learn/data.ts` (kind `translate` validator), `prompts.ts` (kind and task rules), `check.ts`, `exercises.json`. House style: [`learn-quiz/spec.md`](../learn-quiz/spec.md).

## 1. Context

The learner has practised a word group and wants to know which of its words they can produce from meaning alone. Translate sentences is a Step 3 exam: for each word the card shows one Ukrainian sentence, with the part that stands for the word in bold (the cue), and the learner types the English translation. The AI sentence check judges it, but the app has the last word: a translation that is fine but does not use the target word (a synonym for the bold part) is not right (D-39). After the check the learner sees "Good" or one corrected sentence and a short note, and always the model translation with the word in bold. One send per word, no edit and no second try; Skip is always possible. Each word ends as **known** or **repeat** (or, if the check never answered, with no result), and that word result is saved on the session at once. A round has 3 to 5 words; its summary shows "N of n known", each word's label, and the learner's translation next to the model one.

Why now: `hard-decisions.md` Wave 3 builds translate-sentences right after the Quiz. Everything it needs is built: the Worker's data kind `translate` (S-15: Ukrainian `source` without the English word, `cue` an exact part of `source`, English `model` holding the word once) and check task `translate` (S-20, extra = the source sentence); the app service's `LearnDataKind.translate` and `LearnCheckTask.translate`; the kit's `SentenceCheckField` in exam mode with `SentenceResult`, `examLabel` and `examSummaryText` (S-47, S-48); the bolded fixed sentence (S-49); the usable-word rule for Worker-data sentence exercises (S-50, which already names kind `translate`); and the exam-result pattern with its summary vocabulary (S-55, S-56) as built in the Quiz. This is the first sentence exam, so how a sentence exam's summary details read is fixed here for own-sentences and explain-to-friend (S-58).

Committed approach: one `@riverpod` notifier plus one round body on top of the kit (S-30). On open the notifier reads the group's words (S-08), asks the Worker once for kind `translate` for the candidates (S-50), keeps the words whose data is fair (S-57), splits them into rounds of 3 to 5 in group order and shuffles each round once (S-34, S-27). The round body draws the cue card and the prompt, and under them the kit's `SentenceCheckField` in exam mode with task `translate` and the source sentence as `extra`. When the field reports its result, the notifier stores it and, in the same step, records the word result through the sink (S-55). After the word is final, the body shows the model translation with the word in bold and "Next". The spoken variant is cancelled (H-06); there is no Speak mode.

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- **Direction and source (D-37, D-38).** Ukrainian to English, fixed, no setting. Sentences come only from the Worker's kind `translate`, one data call per open; dialogue lines are English and not used. The Worker and its prompt are used as built (no prompt change, so no cache key bump, S-16); the only Worker edit is the registry flip (`available: true`, S-02).
- **Usable words (S-50, S-57).** A candidate is a word to learn of the group with a non-empty trimmed word, translation and row id. Fewer than 3 candidates shows "Not enough words for this exercise" with no Worker call. Otherwise one `fetchData(LearnDataKind.translate, …)` for all candidates in group order. The app then leaves a word out when its value is null ("none" or broken), its `model` does not hold the word exactly once (`holdsWordOnce`), its `cue` is empty or is not an exact part of its `source`, or its `source` contains the word or any other word to learn of the group as a whole word (`matchPlaces`, the D-08 rule widened to the group so the card never shows an English word of the group). The Worker already refuses the first three; the app checks again because a broken cache entry or a stale reply must never put an unfair card on screen. Fewer than 3 left shows the same "Not enough words" line.
- **Rounds and order (D-13, S-34).** `splitRounds(usable, min: 3, max: 5)` in group order (a typed sentence is slow, so 5 at most, as own-sentences); each round's words are shuffled once at open with the kit's `Random` (S-27). Counter "Word n of m" (m = round size), as sentence-patterns.
- **The card (D-34, D-38).** Only the prompt "Translate into English." and the source sentence, with the first occurrence of the cue in bold (pure `cueSpans(source, cue)` in this exercise's folder — one user, so not in the kit, S-05). No English word, translation line, definition, example, speaker or model translation before the word is final.
- **The check (S-47, S-21, D-39).** `SentenceCheckField(word, translation, task: translate, extra: source, mode: exam)`, keyed per round and word. Everything about typing, the pre-check ("Write a full sentence", "Keep it under two hundred characters"), "Checking…", the error line with Retry resending exactly the sent text, the day-limit line without Retry, "Good" / fixed sentence with the word in bold / note, the read-only text and Skip is the kit's, unchanged. The verdict is `judgeCheck`'s: a translation the AI calls fine but that does not use the word is fixed, with the note `Use “<word>” in your sentence.` — so a synonym is repeat (D-39; the small spec's first open question is closed by D-39 with its default).
- **The model translation.** Once the word is final (checked, skipped, or skipped after a failed check), the line "Model translation:" and the `model` with the word in bold (`boldWord`, D-27) show under the field, then "Next". The small spec's "the fixed sentence uses it" for a synonym is narrowed: the AI's fixed sentence is shown as it comes (bolded where it holds the word); the model translation is the place that always shows the word.
- **The exam-result pattern (S-55, S-48).** In the same step that stores a word's `SentenceResult`, the notifier calls `unawaited(ref.read(examResultSinkProvider).record(sessionId: <sessionId>, rowId: <rowId>, exerciseId: 'translate-sentences', label: examLabel(outcome)))` — once per word of a round, never awaited, nothing for `notChecked`. Nothing is recorded on Next, Next round, the summary, Done or Back. The small spec's second open question (save known / repeat) is closed by S-01 / S-22: results are saved.
- **Summary (S-55, S-56, S-58).** Per round: heading `examHeading(known, n)` ("N of n known", n = the round's words); the round's words in asked order, each with `examSummaryText` ("Known" / "Repeat" / "Not checked") and a detail line: known "Yours: <sentence>"; fixed or not checked "Answer: <model> · Yours: <sentence>"; skipped "Answer: <model> · Skipped". One list in asked order, not two separate lists (the kit summary is one list; the small spec's "Known and Repeat lists" are its labels). Buttons: "Next round" or, after the last round, "Done" — the kit's, unchanged.
- **No Repeat button (S-58).** Unlike the Quiz, there is no "Repeat": the model translation of every word was just shown, and the Worker's cache would give the same sentence again for 30 days, so a repeat of the same card tests memory of the shown answer, not the word. `againLabel` stays null.
- **Leaving.** Back at any point returns to the learn page with no dialog; results already recorded stay; a reply that arrives after leaving is ignored and records nothing (the field ignores it after dispose). Opening again starts at round 1 with the same sentences (cached) and a new shuffle.
- **Copy chosen here:** title "Translate sentences", counter "Word n of m", prompt "Translate into English.", "Model translation:", "Next", summary heading "N of n known", results "Known" / "Repeat" / "Not checked", details as above. The kit's and frame's lines stay as built.
- **Files:** `lib/features/learn/translate_sentences/` (`translate_sentences_notifier.dart`, `translate_sentences_screen.dart`, S-30; `cueSpans` and the pure detail builder live in the notifier or screen file); `case 'translate-sentences'` in `exerciseScreen` (`lib/features/learn/exercise_screens.dart`); `available: true` in `vocab-photo-api/src/learn/exercises.json` and `lib/features/learn/exercises.dart` (S-02). Unchanged: every kit file, `learn_api_service.dart`, `exam_result_sink.dart`, `word_result.dart`, the Worker code.

## 2. Goals

- The learner can take a fair translation exam over any selected group that tells them, word by word, which words they can produce from meaning alone.
- Every word that ends with a checked or skipped answer leaves a saved word result on its session at that moment; a word whose check never answered, or that was never reached, leaves none.
- A translation that avoids the target word is never counted as known, and the learner always sees the model translation with the word after each answer.

## 3. Non-goals

- No spoken input or Speak mode (H-06, D-28, D-35): typed only.
- No English → Ukrainian direction and no direction setting (D-37).
- No "Repeat" attempt and no new sentences on reopen in v1 (S-58; the cache keeps a word's sentence for 30 days).
- No hint, second try, edit after the check, speaker, or model translation before the answer (D-34).
- No Worker code or prompt change and no kit change (§1).
- No screen that lists saved results and no effect of results on the word row, sharing, exports or the lightning icons (S-22).
- No play on the shared page or the web learn page (D-11, H-07).

## 4. User stories

### US-01: Start the exam for a group
**As a** learner
**I want** to tick Translate sentences in Step 3 and press Start with a word group selected
**So that** I am examined on exactly that group's words

### US-02: Translate a Ukrainian sentence with the word
**As a** learner
**I want** a Ukrainian sentence with the part for the word in bold, and one typed English translation checked at once
**So that** I find out whether I can produce the word from its meaning

### US-03: Fair judging of the word
**As a** learner
**I want** a correct translation with the word in any form to count as known, and one that avoids the word to be marked repeat with the reason
**So that** the result is about this word, not about any good English

### US-04: Skip a word I cannot translate
**As a** learner
**I want** a Skip on every word until it is final
**So that** I can move on, and the word is marked to repeat

### US-05: Recover from a failed check
**As a** learner
**I want** a plain error line with Retry that resends my exact translation when the check fails, and a clear line when the day's limit is reached
**So that** a bad connection never costs me a try or a wrong result

### US-06: See my round's results
**As a** learner
**I want** a summary with "N of n known", each word's label, my translation and the model translation
**So that** I see what to work on

### US-07: Keep my results
**As a** learner
**I want** each finished word's result saved on the session at once, also when I leave early or the session is from History
**So that** the app knows which words I know, without changing my words

### US-08: A clear screen when the exam cannot run
**As a** learner
**I want** a plain message when the group is too small or the sentences cannot be loaded, with Retry where it can help
**So that** I am never left on a broken screen

## 5. Acceptance criteria

### Opening and rounds

### AC-01 (US-01) — happy path
**Given** the app after this feature and a selected word group of 8 words to learn, each with a translation, for which the Worker returns fair sentences
**When** the learner opens the learn page, ticks "Translate sentences" in Step 3 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exam opens with the title "Translate sentences" and "Word 1 of 4" after the frame's loading state, and the 8 words are asked in two rounds of 4.

### AC-02 (US-01) — domain invariant
**Given** groups with 3, 5, 6, 9, 11 and 19 usable words
**When** the exam opens
**Then** the rounds are 3; 5; 3+3; 5+4; 4+4+3; 5+5+5+4 words — never a round under 3 or over 5 — each round holds the next words in group order, and inside a round the words come in a shuffled order.

### AC-03 (US-01) — domain invariant
**Given** the same group, the same session and the same random seed
**When** the exam opens twice
**Then** both times the rounds hold the same words in the same order; with a different seed only the order inside each round may change.

### AC-04 (US-08) — error
**Given** a selected group with fewer than 3 words to learn that have a translation
**When** the learner starts the exam
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked.

### AC-05 (US-08) — error
**Given** a group of 5 words to learn with translations, for which the Worker has no sentence for 2 words, and for a third returns a Ukrainian sentence that contains the English word, or a bold part that is not in the sentence, or a model translation without the word
**When** the exam opens
**Then** those 3 words are left out, only 2 remain, and only "Not enough words for this exercise" and "Back" show; with 3 fair words left the exam runs one round of 3.

### AC-06 (US-08) — error
**Given** the phone is offline, or the Worker fails, times out or has no exercise storage, while the sentences load
**When** the exam opens
**Then** only "Could not load the exercise. Check the connection and try again." and "Retry" show (no partial round); Retry asks again and, on success, word 1 shows.

### AC-07 (US-08) — error
**Given** the Worker says the day's exercise data allowance is used up (or that requests are too frequent) while the sentences load
**When** the exam opens
**Then** "Today's exercise limit is reached. Try again tomorrow." shows with Back and no Retry (or "Too many requests. Wait a moment and try again." with Retry); no word is asked and no word result is saved.

### AC-08 (US-01) — cross-context
**Given** a group of 6 words to learn, one with an empty translation
**When** the exam opens
**Then** the Worker is asked once, for the 5 words with a translation only, with each word's translation so the sentence follows that sense; the same group opened again within 30 days shows the same sentences and takes nothing from the daily data allowance.

### The card and the answer

### AC-09 (US-02) — happy path
**Given** a word "shore" with translation "берег", whose Worker sentence is "Ми довго сиділи на березі." with the bold part "березі"
**When** its card shows
**Then** "Word n of m", "Translate into English.", the sentence with only "березі" in bold, and a text field with the keyboard open (no autocorrect, no suggestions, the action key is Send) and "Skip" show; no English word of the group, no translation line, no speaker and no model translation are visible.

### AC-10 (US-02) — error
**Given** a card with the field empty, holding only spaces, or one word
**When** the learner presses Send
**Then** nothing is sent, "Write a full sentence" shows, the field stays editable and the keyboard stays open; no try is used.

### AC-11 (US-02) — error
**Given** a translation longer than 200 characters
**When** the learner presses Send
**Then** nothing is sent and "Keep it under two hundred characters" shows.

### AC-12 (US-03) — happy path
**Given** the card for "shore"
**When** the learner sends "We sat on the shore for a long time." (or "…on the shores…", any form of the word) and the check finds no error
**Then** "Checking…" shows while it runs, then "Good", the line "Model translation:" with the model sentence and "shore" in bold, and "Next"; the field is read-only, Skip is gone, and the word is known.

### AC-13 (US-03) — domain invariant
**Given** the card for "shore"
**When** the learner sends "We sat on the beach for a long time." and the check calls it correct English
**Then** the word is repeat: the note "Use “shore” in your sentence." shows with any corrected sentence the check gave (the word in bold where it appears), and the model translation with "shore" in bold shows.

### AC-14 (US-03) — happy path
**Given** the card for "shore"
**When** the learner sends a translation with a grammar or spelling error, or one that does not translate the sentence
**Then** one corrected sentence (the word in bold) and a note of at most 100 characters show, then the model translation; the word is repeat.

### AC-15 (US-03) — domain invariant
**Given** a check that calls the translation not fine but returns a "corrected" sentence equal to the learner's apart from case, outer spaces and end punctuation, and the translation uses the word
**When** the result shows
**Then** "Good" shows and the word is known (the check fixed nothing).

### AC-16 (US-02) — domain invariant
**Given** a checked word
**When** the result shows
**Then** the field cannot be edited or sent again, there is no second try in this round, and only "Next" moves on; there is no way back to an earlier word.

### AC-17 (US-04) — happy path
**Given** a card before any check is sent
**When** the learner taps "Skip"
**Then** no check is sent, the field is read-only, the model translation with the word in bold and "Next" show, and the word is repeat.

### Failed checks and the day cap

### AC-18 (US-05) — error
**Given** a sent translation whose check does not answer within 15 seconds (or the phone is offline, or the check fails)
**When** the check gives up
**Then** "Could not check the sentence. Check the connection and try again." and "Retry" show; the typed translation stays and cannot be edited; no result line, model translation or word result shows.

### AC-19 (US-05) — happy path
**Given** the failed check of AC-18
**When** the learner taps "Retry" and the check answers
**Then** exactly the same translation is sent again (it is not a second try), and the result shows as in AC-12..AC-14 with one word result.

### AC-20 (US-05) — error
**Given** a sent translation and the Worker says the day's check allowance is used up
**When** the reply arrives
**Then** "Today's exercise limit is reached. Try again tomorrow." shows with no Retry; "Skip" stays; Skip ends the word as "Not checked" with the model translation, and no word result is saved for it.

### AC-21 (US-05) — error
**Given** a failed check that was never retried to an answer
**When** the learner taps "Skip"
**Then** the word is "Not checked" in the summary and has no word result (neither known nor repeat).

### Saving word results

### AC-22 (US-07) — cross-context
**Given** an exam on a session
**When** a word becomes final (its check answers, or Skip)
**Then** at that moment exactly one word result is saved on that session for that word, from the exam "translate-sentences", with the label shown later in the summary (known or repeat) and the time; the learner does not wait for it and sees nothing about it.

### AC-23 (US-07) — domain invariant
**Given** a round of 4 words where 3 end checked or skipped and 1 ends not checked
**When** the learner taps Next, sees the summary and taps "Next round" or "Done"
**Then** none of these taps saves a word result; over the round exactly 3 results are saved, none for the not-checked word and none for words of other rounds not yet shown.

### AC-24 (US-07) — domain invariant
**Given** a round where 2 words are final and a third word's check is still running
**When** the learner leaves with Back
**Then** exactly those 2 word results are saved; the third gets none even if its reply arrives later; opening the exam again starts at round 1, word 1.

### AC-25 (US-07) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner takes the exam
**Then** only that session's words are used and sent, the word results are saved on that session, and its words, groups, last-changed time and History position are unchanged.

### AC-26 (US-07) — cross-context
**Given** a session with saved word results from this exam
**When** the learner shares, publishes, exports (any of the five formats) or copies its words, or the lightning icons are shown
**Then** none of them contains or reacts to the results.

### Summary

### AC-27 (US-06) — happy path
**Given** a round of 4 asked in the order "shore" (known, sent "We sat on the shore."), "borrow" (fixed, sent "I took a book."), "receive" (skipped) and "allow" (not checked, sent "They let us go.")
**When** the summary opens
**Then** it shows "1 of 4 known", then the 4 words in that order with "Known", "Repeat", "Repeat", "Not checked"; under "shore" "Yours: We sat on the shore."; under "borrow" "Answer: <its model translation> · Yours: I took a book."; under "receive" "Answer: <its model translation> · Skipped"; under "allow" "Answer: <its model translation> · Yours: They let us go."; and "Next round" when a round follows.

### AC-28 (US-06) — happy path
**Given** the summary of the last round
**When** it shows
**Then** the button is "Done" (no "Repeat" button, even with repeat words); Done returns to the learn page (or opens the next ticked exercise, as today); "Next round" on an earlier summary opens the next round at "Word 1 of m".

### People

### AC-29 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 3
**Then** Translate sentences is listed with the same name and step as in the app and cannot be played there; no word result can come from the web.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per load Retry) | 0 when fewer than 3 candidates; else exactly 1 data call of kind `translate` holding only the candidates; 0 checks on open | widget test with a counting `learnApiService` fake |
| Checks per word | exactly 1 per valid Send or check Retry; 0 for a refused text, Skip, Next, Next round and the summary | widget test with a counting fake |
| Word results per round | exactly 1 `record` per word whose outcome is right, fixed or skipped, at the moment it is final; 0 for not checked, Next, Next round, the summary, Done, Back and unreached words; exercise id `translate-sentences`; the session id passed through | notifier test with a recording `ExamResultSink` fake |
| Final answer to model translation shown | ≤ 100 ms after the field reports, never waiting for the result save | widget test pumps one frame with a sink whose `record` never completes |
| Send to verdict, good network | p50 ≤ 4 s, worst case ≤ 15 s then the error line | manual check before ship; kit timeout test exists |
| Start to first card, cached group | ≤ 1.5 s | manual check before ship |
| Fair cards | 0 cards whose sentence shows an English word of the group, whose bold part is missing, or whose model translation lacks the word once | notifier tests over each drop rule |
| Determinism | same seed + same session → same rounds and order, 100% | notifier test with `Random(seed)` over `exerciseRandomProvider` |
| Kit and Worker reuse | 0 changed lines in `lib/features/learn/kit/`, `learn_api_service.dart`, `exam_result_sink.dart`, `word_result.dart` and `vocab-photo-api/src/` except `exercises.json` | `git diff` at `sdd:review` |
| Test coverage | every AC has a unit or widget test; AC-29 by the Worker learn-page test; AC-26 by one result written by this exam over the real store | `tool/test.sh changed` |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, translations and typed translations.
- **Personal data touched:** the word results (row id, exam, label, time) on the learner's own session, as S-22 allows. Each sent translation leaves the phone for one check with the word, translation and source sentence (S-20); the Worker never caches or logs it (S-20, S-24); the app shows it only on screen and in the summary and never stores it.
- **AuthZ/AuthN impact:** none new. Both Worker routes stay behind the app's secret (S-14, S-20); results are written only by the app on the device (S-23); no play surface on the web.
- **Abuse cases:**
  - Partner tries to take the exam from a web link: the web learn page lists it only (AC-29).
  - Prompt injection through a typed translation: the check sends it as data only (S-20 prompt rule); the app's `judgeCheck` decides whether the word is used, not the AI.
  - Draining the check allowance: one check per valid Send or Retry, refused texts are never sent; the Worker's day cap (500 checks) and per-IP limiter apply (H-03, S-18).
  - Results leaking through sharing or exports: never part of the word row or any shared form (AC-26).
  - A learner reopening to turn repeat into known with the remembered model sentence: possible (same cached sentence); the newest result wins (S-22); accepted for v1, no score to inflate (S-58).
- **Security review:** N/A — no new data flow, route, secret or storage beyond the approved word result and the built learn routes.

## 7. Metrics / KPIs

The app has no usage analytics; checked at review from the owner's own use, saved word results in a debug run, and the Worker's `learn data` / `learn check` log lines (S-24).

- **Groups that can take the exam** (owner's groups showing word 1, not "Not enough words…") — baseline: 0 (not available). Target: at least 9 of 10 within 14 days of the owner's deploy.
- **Words dropped as unfair** (words left out after the data call, over candidates sent, from `learn data` outcomes and a debug count) — baseline: unknown. Target: ≤ 10% within 30 days; above that, tighten the kind `translate` prompt in its own change.
- **Finished words with a saved result** (saved results over words ending right, fixed or skipped, debug run) — baseline: 0. Target: 100% from the first release.
- **Checks that end in "Not checked"** (from `learn check` failures over checks) — baseline: unknown. Target: ≤ 5% on a good network over the owner's first 10 rounds.

## 8. Open questions

- [ ] Real sentences and checks need the owner's learn-kit deploy steps (the `vocab-learn-data` KV namespace, `0006_learn_allowance.sql`, deploy, S-01); until then the exam shows the load error line (AC-06). Default now: build and flip `available`; the web list needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.
- [ ] CLAUDE.md rules 3 and 5 list approved visible changes and models; the approval lists are the owner's edit (S-01). This exercise's screen is approved with every exercise's screens and adds no model or package. Default now: no CLAUDE.md edit by agents. — owner: Maksym, due: any time.
