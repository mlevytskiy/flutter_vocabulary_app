---
status: proposed
updated_at: "2026-10-14"
reads: "README.md, decisions.md (D-01..D-43), learn-screen-briefs.md, the 15 specs; lib/features/learn/, vocab-photo-api/src/{learn,story}/"
---

# Ten hard decisions for implementing the learning exercises

A hard decision is one that is expensive to undo, or one the specs leave open or contradictory. Each
entry: why it is hard, the options, the chosen solution, what it overrides, and whether CLAUDE.md
requires the owner. Agent proposals (2026-10-14); the owner may revise any.

## H-01 One exercise engine or one screen per exercise
**Why hard.** Fifteen specs share the same frame (round split, "Not enough words", error line + Retry, summary, Next round / Done, typed field rules D-19, the check result line D-24) but have five unrelated interactions (match board, grid, card flip, typed answer, timer). A generic engine chosen now is the costliest thing to undo; fifteen copies of the frame are the costliest thing to maintain.
**Options.** (a) One `ExerciseEngine` with a question model and renderers per type. (b) Fully separate screens. (c) A thin shared kit; each exercise owns its body and notifier.
**Solution: (c).** One typed route `ExerciseRoute(exercise, sessionId, groupId)` (next to `StoryRoute`; rule 1) whose `build` switches on the frozen id. One `lib/features/learn/kit/`: `ExerciseScaffold` (loading / error+Retry / not-enough / round / summary states), `splitRounds(words, min, max)` (D-02, D-13), `ResultSummary`, `TypedAnswerField` (D-19), `CheckResultLine` (D-24), pure `buildQuestion` (D-14), `matchTyped` (D-18), `maskWord`/`boldWord` (D-08, D-27; port `dialogue_match.dart` rules). Each exercise: one `@riverpod` notifier for its round data, one body widget, nothing in the kit that only one exercise needs. Why: the states are shared, the interactions are not; a pure-function kit is tested once and never blocks a screen.
**Changes.** Nothing in the specs; fixes the structure D-01, D-14, D-18, D-24 assume. The learn page's `_start` gets one more branch (`ExerciseRoute` for every available id) instead of `ComingSoonRoute`.
**Needs owner.** No.

## H-02 Where AI exercise data is generated, cached and paid for
**Why hard.** Synonyms, definitions, clues, gap sentences, patterns and translation sentences are all "one call per group" (D-03), but the specs say nothing about the model, the key the cache is under, the store, or the cost cap; the story allowance (20 runs a day) is far too small to share, and the app may keep nothing (rule 5).
**Options.** (a) One generic endpoint on the Worker, cache in KV per word, fixed cheap model. (b) One endpoint per kind, each with its own prompt and table. (c) Generate on the phone (no secret, no cache) — impossible, the keys are Worker secrets.
**Solution: (a).** `POST /learn/data {kind, words:[{rowId, word, translation}]}`, kinds `synonym | definition | clues | sentence | pattern | translate`, secret-gated like `/story/*`. The Worker reads KV `learn:v1:<kind>:<word>|<translation>` (lowercased; the translation fixes the sense, D-06), asks the fixed grouping model (`GROUPING_MODEL`, Haiku) once for the misses only, in one JSON reply with `"none"` allowed, writes each answer back with the 30-day TTL `/define` uses, and returns per rowId. Not on the offered-model list and not selectable (no picker UI, no visual change). Cost cap: a new D1 day counter `all_learn_data` taken the way `takeStoryRun` takes `all_story_runs`, limit 200 AI calls per UTC day app-wide (cache hits take nothing); the existing per-IP limiter (20 requests / 60 s) stays. The app holds the data in the screen's notifier only.
**Changes.** Implements D-03, D-06, D-20 source 2, D-38 and sentence-patterns call 1; one Worker migration (`0006_learn_allowance.sql`, a Worker table, not an app model).
**Needs owner.** No (note the ~$0.001 per group call in the ADR).

## H-03 The sentence check: model, cost, limits
**Why hard.** D-24 is one uncached AI call per learner sentence for four exercises; it is the only per-answer cost in the app and the only call a learner waits for inside a round. Too cheap a model gives unfair exams; too strict a cap stops a round midway; the per-IP limiter already counts story polling (12 requests a minute).
**Options.** (a) Fixed Haiku, strict JSON, 15 s timeout, day cap. (b) The learner's story model (Sonnet by default), via the model picker. (c) Batch a round's sentences into one call at the end.
**Solution: (a) with a guard.** `POST /learn/check` with the D-24 body, fixed Haiku, `maxOutputTokens` 300, Worker timeout 12 s so the app's 15 s (D-25) wins. A D1 day counter `all_learn_checks`, limit 500 per UTC day; refusal is `429 day_limit` and the app shows the story's day-limit line pattern. Exam screens do not poll the story tracker, so the 20/60 s limiter is not reached by one learner. No batching: D-26 needs a result per Send, and (c) would make Retry resend a whole round.
**Changes.** Refines D-24, D-25; adds the two allowance constants to the Worker (no spec change).
**Needs owner.** No.

## H-04 Who judges a sentence: the AI or the app
**Why hard.** The exam label (known / repeat) hangs on `usesWord` and `ok` from a non-deterministic model; one unfair "repeat" on a correct sentence breaks trust, and a saved result (H-05) makes it permanent.
**Options.** (a) Trust the AI's JSON as is. (b) The app decides `usesWord` itself, the AI judges only grammar and task. (c) Two AI calls and a vote.
**Solution: (b).** The app computes `usesWord` with the Dart word-match port (whole word plus -s/-es/-ed/-ing, phrases in order; `lib/core/dialogues/dialogue_match.dart` rules) before sending; the Worker also reports it, but the app's value wins. `ok` is then `usesWord && usesTask && noError`. Guard: if the AI returns not-`ok` but `fixed` equals the sentence after trimming, lowercasing and dropping end punctuation, the app treats it as `ok` (the model "fixed" nothing). For task `explain` (D-40) the app's `usesWord` must be false. Prompts carry a fixed few-shot block; `temperature` is not sent (the adapter does not support it today).
**Changes.** Refines D-24, D-39, D-40; sentence-patterns "inflected forms are fine" now holds for all four exercises.
**Needs owner.** No.

## H-05 Saving the Step 3 result, and whether Step 3 is worth building without it
**Why hard.** The owner's Step 3 goal is "tell the app per word which are known"; D-33 saves nothing, so a Step 3 round that only shows a summary misses the goal. Saving needs a new record or a WordPair field (rule 5), and WordPair is copied, exported, published and compared everywhere, so a field there leaks to Anki, the shared page and the lightning rules.
**Options.** (a) Ship Step 3 show-only (D-33) and never save. (b) A `WordPair.learnResult` field. (c) A new embedded list on `Session`: `WordResult {rowId, exerciseId, label (known|repeat), at}`, append-only, latest wins. (d) Do not build Step 3 until the record is approved.
**Solution: (c), built behind an interface.** Step 3 exercises are worth building now because their mechanics (exam rules, check, builders) are independent of storage. Every exam writes through an `ExamResultSink` (a provider in `lib/core/providers.dart`); the first implementation is a no-op, the second appends `WordResult` to the session once the owner approves. The record never touches WordPair, publishing, exports or the lightning icons; the Quiz's "Repeat" and own-sentences' "Practise repeat words" become possible once it exists. Not (b): WordPair's `toJson` is the publish and export shape.
**Changes.** D-33 becomes "no-op sink until approved"; D-04 "later" becomes "this record"; closes the Step 3 open questions in quiz, own-sentences, translate-sentences, explain-to-friend, remember-or-not ("Not yet" stays unsaved, D-21).
**Needs owner.** Yes: a new domain model (`WordResult`, ADR needed) — rule 5.

## H-06 Speech-to-text
**Why hard.** Two list items (the spoken variants) and parts of chain-story and explain-to-friend exist only for speech; the app has no recogniser and no recorder, and both the on-device route and the Worker-transcription route need a new package (recording audio is a plugin too, so option (b) in own-sentences-spoken does not avoid rule 5).
**Options.** (a) On-device `speech_to_text`-style plugin (new package). (b) Record on the phone (new package) and transcribe on the Worker (cost, audio leaves the phone). (c) No speech in this plan.
**Solution: (c) now; (a) if the owner ever wants it.** The two spoken items are cancelled as list items; their files stay as the Speak-mode delta (D-35) to build the day a package is approved. Explain-to-friend keeps "With a friend" (no speech, no AI). Recommend (a) over (b): free, offline, no audio off the phone, no Worker cost; the exam only needs the transcript.
**Changes.** own-sentences-spoken, translate-sentences-spoken → `cancelled`; D-28, D-35, D-36 stand; `exercises.json` / `exercises.dart` drop the two ids (never available, so no web link breaks).
**Needs owner.** No for cancelling; yes (a package) if Speak mode is wanted.

## H-07 "Involve people" versus D-11
**Why hard.** The owner asked for exercises that involve people; D-11 defers every shared-page feature. The shared page does have live writes and a change feed for rows, so "no live state" is not quite true, but a buzzer, turns or votes need new tables, page UI, identity and write-back under the row id — the same storage question as H-05, three times over.
**Options.** (a) Build shared-page live play now. (b) In-person modes on one phone, no network. (c) Defer all people features.
**Solution: (b) in v1, (a) after H-05.** "People" in v1 means a person next to the learner: explain-to-friend "With a friend" (built as specced). No new pass-the-phone modes are added to other exercises in this plan. Shared-page play gets its own spec once `WordResult` exists, because every people feature wants to write a result back to a row.
**Changes.** Confirms D-11; guess-my-word, match-synonyms People sections stay "later".
**Needs owner.** No (a product call the owner should see).

## H-08 Too many exercises: what to cancel
**Why hard.** Thirteen planned items on three cards; three of them are "type a sentence, the AI fixes it" (sentence-patterns, own-sentences, chain-story) and three are "find the word from its meaning" (match-definitions, pick-the-answer B, guess-my-word). Every item costs a screen, tests, a Worker kind and a row on the Learn screen, and a weak item dilutes the strong ones.
**Options.** (a) Build all 13. (b) Cancel the two with the lowest value per cost. (c) Merge pairs behind switches (the specs rejected this for antonyms).
**Solution: (b).** Cancel **match-antonyms**: most photo vocabulary is nouns, which have no opposite, so the usual outcome is "Not enough words with opposites"; a separate AI kind for that is not worth a row (one day to add later on the board). Cancel **chain-story**: L size, needs a paid story first, and without dictation (H-06) and turns (H-07) it is a third typed-sentence check with a plot; sentence-patterns gives the scaffold, own-sentences the exam. Keep guess-my-word (graded clues are a distinct mechanic) and quiz (the only cheap exam).
**Changes.** match-antonyms, chain-story → `cancelled`; D-01 covers two boards, not three; D-30 has no user until a story exercise returns.
**Needs owner.** No.

## H-09 Definitions: `/define` first sense or the sense of the translation
**Why hard.** D-09 takes the Merriam-Webster first sense when the row has no definition, but D-06 says every AI answer must follow the translation's sense. A first-sense definition of "bank" for a learner whose translation is "берег" makes match-definitions unwinnable, and the learner cannot tell why.
**Options.** (a) Keep `/define` first sense. (b) Sense-aware definition from `/learn/data` kind `definition` (H-02). (c) `/define` all senses and let the AI pick.
**Solution: (b).** A row's stored `definition` still wins (the learner's chosen sense); an empty one is filled for the round from `/learn/data` kind `definition`, which gets word and translation. `/define` is not used by exercises. Clue 3 of guess-my-word is the same text.
**Changes.** Overrides D-09's "/define" branch (the "never written to the word" and "a translation is never a stand-in" parts stay); match-definitions "What it uses" and the README "define endpoint" dependency.
**Needs owner.** No.

## H-10 The Learn list change and the build order
**Why hard.** The ids are frozen and copied in three places (`exercises.json`, `exercises.dart`, the test), the list is what the Learn screen cards and the Worker's `/s/:id/learn` page show, and rule 3 forbids visible changes without approval. Adding 4 ids, removing 4 (H-06, H-08) and moving pick-the-answer to Step 1 is one visible change that every exercise depends on, so it must come first and once.
**Options.** (a) Change the list per exercise as each ships. (b) One registry commit at the start, every new id `available: false`, then flip ids as they ship. (c) Keep the old list and hide new exercises elsewhere.
**Solution: (b).** One commit: add `guess-my-word` (1), `sentence-patterns` (2), `explain-to-friend` (3), `quiz` (3); remove `match-antonyms`, `chain-story` is never added, drop the two spoken ids; `pick-the-answer` → stage 1; names and subtitles from learn-screen-briefs.md. Then the waves below. Shipping an exercise flips its `available` only.
**Changes.** README table, exercises.json/.dart, `learn_exercises_test.dart`, Worker learn page copy.
**Needs owner.** Yes: a visible change to the Learn screen rows (rule 3).

## Cancelled / merged exercises
- **match-antonyms** — cancelled by H-08: most groups have too few words with opposites; one day to add on the match board later.
- **chain-story** — cancelled by H-08: needs a paid story, loses its point without speech (H-06) and turns (H-07); third sentence-check exercise.
- **own-sentences-spoken** — cancelled as a list item by H-06: no speech-to-text without a package; file kept as the Speak-mode delta (D-35).
- **translate-sentences-spoken** — cancelled as a list item by H-06: same.
- Already merged by the specs, unchanged: Flashcards → remember-or-not; Writing practice → own-sentences; Examples from your world → Mnemonic story theme (later).

## Resolved conflicts (decisions.md "Conflicts noticed")
1. D-09 vs D-16 (translation as a stand-in): **D-16 wins** for offline exercises; D-09's `/define` branch is replaced by H-09, its "never a stand-in" part stays for match-definitions.
2. D-19 vs D-34 (retry, Show answer): **D-34 wins** in Stage 3 (D-41); D-19 holds in Stage 2 (fill-the-gaps only, now).
3. D-17 vs D-34 (instant colour): **D-34 wins** in Stage 3 (D-43); D-17 holds for pick-the-answer.
4. D-12 vs D-31 (numeric score): **D-31 wins** in Stage 3; D-12 holds in Stages 1–2 (guess-my-word 0–3, fill-the-gaps 0–2). Quiz is removed from D-12's list.
5. D-04 vs D-33 (saved results): **H-05 wins**: no-op sink now, `WordResult` once approved; D-04 reads "Step 3 writes WordResult".
6. D-22 vs D-34 (speaker in the Quiz): **D-34 wins**; the Quiz is removed from D-22's list. Speaker only in Stages 1–2 after reveal.
7. D-20 vs D-38 (dialogue lines for translation): **D-38 wins**; D-20's dialogue-line branch applies to fill-the-gaps and the Quiz gap only.

## Build order
Each wave ships on its own; no wave depends on an owner decision except wave 3.
- **Wave 0 — registry and kit.** H-10 registry commit (after the owner's OK). `ExerciseRoute`, the kit (H-01), Worker `/learn/data` and `/learn/check` with their allowances (H-02, H-03). First exercises, both without network: **pick-the-answer** (proves route, kit, `buildQuestion`, summary) and **remember-or-not** (card flip, TTS). Why first: they show the kit works end to end at zero AI cost and need no owner input.
- **Wave 1 — Step 1 with AI data.** **match-synonyms** (the match board + kind `synonym`), **match-definitions** (kind `definition`, H-09), **fill-the-gaps** (kind `sentence`, D-18, dialogue lines first). Why: one data endpoint exercised by three kinds before any check call exists.
- **Wave 2 — Step 2 production.** **sentence-patterns** (first user of `/learn/check`, H-04 guard), **guess-my-word** (kind `clues`, grid). Why: the check contract is proven on a scaffolded, non-exam exercise before exams depend on it.
- **Wave 3 — Step 3 exams (after H-05 is decided).** **quiz** first (reuses two builders, no check cost, the cheapest exam), then **translate-sentences** (kind `translate`), **own-sentences**, **explain-to-friend**. The `ExamResultSink` is the no-op if the owner has not yet approved `WordResult`; wiring the real sink is one task once approved.
- **Not built:** match-antonyms, chain-story, the two Speak modes (H-06, H-08).
