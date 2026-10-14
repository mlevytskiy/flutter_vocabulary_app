---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-14"
feature_size: "M"
---

# Spec — learn-kit

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01, H-02, H-03, H-04, H-05, H-09, H-10 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-01..D-43; the interface decisions of this spec are logged there as S-01..S-24), [`learn-exercises/README.md`](../learn-exercises/README.md), [`learn-exercises/learn-screen-briefs.md`](../learn-exercises/learn-screen-briefs.md), the clarified exercise specs (only for what the kit must serve), [`docs/architecture.md`](../../architecture.md), `lib/features/learn/`, `lib/router/routes.dart`, `lib/core/dialogues/dialogue_match.dart`, `vocab-photo-api/src/{learn,story,define.ts,index.ts}`.

## 1. Context

The Learn screen lists fifteen exercises in three steps; only Mnemonic story and Dialogs from movie are built. The remaining exercise specs (Wave 0 to Wave 3 of `hard-decisions.md`) all share one frame — words of one word group split into rounds, a "not enough words" screen, an error line with Retry, a summary, typed-answer rules, a sentence check — and most need AI-made data (synonyms, definitions, clues, sentences, patterns, translation prompts) or an AI judgement of a learner's sentence. Built one by one, each exercise would copy the frame, its own server call and its own cost rules. The learner would see fifteen slightly different behaviours, and the owner would have fifteen places where AI spending could leak.

Why now: the exercise specs are clarified and the owner has asked for all exercises to be implemented (2026-10-14). Every exercise of Waves 0 to 3 depends on this base. It has to come first, once, and be tested on its own before any exercise screen is built.

Committed approach (H-01, H-02, H-03, H-04, H-05, H-10): a thin shared kit, not an engine. It holds **one way to open an exercise** for a selected word group, **one screen frame** with five states (loading, failed with Retry, not enough words, round, summary), and **pure, tested helpers** (round splitter, question builder, typed-answer matcher, word masking and bolding, sentence-check verdict). Each exercise keeps its own body and its own screen data. On the server there is **one exercise data service**: per word, in the sense of its translation, cached per word and translation for 30 days, and generated in one AI call per group for the misses only. There is also **one sentence check service**: one call per learner sentence, never cached. Both use a fixed cheap AI, are reachable only by the app, and each has its own app-wide daily allowance, separate from the story allowance. The app, not the AI, decides whether a sentence uses the word. Step 3 exams record a **word result** (known or repeat) per word on the session through one shared result sink. The Learn list is changed once, here, to the final plan.

¶4 Traceability, owner decisions and assumptions:
- **Owner decisions (2026-10-14, relayed by the coordinator of this spec pass):** (1) H-05 approved: a `WordResult` list on the session holds Step 3 results; the kit provides the real result sink, not a no-op. (2) H-10 approved: the owner asked for all exercises to be implemented, so the Learn list change (rule 3) is approved. (3) Worker work is local only: the owner creates the new Cloudflare bindings and deploys; this spec lists them (§6.2). The approval lists in CLAUDE.md rules 3 and 5 do not include these yet. Adding them is the owner's own edit (§8).
- H-09 is applied: the data service's `definition` kind replaces D-09's dictionary branch for exercises; the dictionary feature (definition-mode) is unchanged.
- The approved list (H-10) keeps the cancellations of H-06 and H-08 (match-antonyms, chain-story, the two Speak modes). Whether "implement all exercises" also undoes them is in §8; the default is no.
- Assumptions made without the owner (easy depth, recorded for veto): a round uses only words of the selected word group, and distractors come from the same session only (S-08). The data service accepts at most 19 words per request (the largest word group) (S-14). The daily allowances are 200 AI data calls and 500 sentence checks (H-02, H-03). A word result is written as soon as that word's result is final, not at the end of the round (S-23).
- The kit adds no visible change by itself: no exercise flips to available in this feature. The frame's look becomes visible with the first exercise (pick-the-answer). The Learn list change is the one visible change here.

## 2. Goals

- Every later exercise is built on one shared frame and a set of helpers that are tested once, so the learner meets the same loading, error, not-enough, round and summary behaviour everywhere and no exercise copies them.
- AI exercise data and sentence checks come from one bounded, cached, app-only service, so opening a group twice costs nothing and a day's AI spending has a hard ceiling.
- Sentence and typed-answer judgements are fair and repeatable: the word-use rule and typo tolerance are decided in the app by deterministic rules, not by the AI's mood.
- Step 3 exams leave a lasting known / repeat mark per word, kept on the phone, for later "repeat" features.

## 3. Non-goals

- **Any exercise screen.** pick-the-answer, remember-or-not and the rest are their own specs (Waves 0–3). The kit ships with every new exercise still "Coming soon".
- **Exercises on the web learn page.** The web page lists the same exercises but keeps the coming-soon page for every new one. A shared link is the only credential there, and it must never spend AI money.
- **Showing word results anywhere.** The kit records them and offers a way to read them. Lightning icons, the Words table, the shared page, exports and publishing never see them. Using them ("Repeat", "Practise repeat words") belongs to the exam specs.
- **Choosing the AI for exercises.** The exercise AI is fixed on the server and is not on the offered-model list. No picker and no settings UI.
- **Speech input, people modes and cancelled exercises** (H-06, H-07, H-08).

## 4. User stories

### US-01: Open an exercise for a group
**As a** learner
**I want** Start to open the exercise I ticked for the word group I selected
**So that** I practise exactly the words I chose

### US-02: One predictable exercise frame
**As a** learner
**I want** every exercise to load, fail, refuse too-small groups, split rounds and sum up the same way
**So that** I always know what is happening and how to go on

### US-03: Fair typed and choice answers
**As a** learner
**I want** my typed answers forgiven for one phone typo but not for a wrong word, and choice questions with exactly one right option
**So that** a result reflects what I know, not my keyboard

### US-04: Exercise data in my word's sense
**As a** learner
**I want** synonyms, definitions, clues and sentences to follow the sense of my translation, and to load fast when I come back
**So that** the exercise is winnable and I do not wait twice

### US-05: A fair sentence check
**As a** learner
**I want** my sentence checked once, with a fix and a short note when it is wrong
**So that** I learn from my mistakes and am not marked down unfairly

### US-06: Bounded AI spending
**As the** owner
**I want** exercise AI calls to be reachable only by the app, cached where possible and capped per day
**So that** a leaked secret or a bug cannot run up the bills

### US-07: The planned Learn list
**As a** learner
**I want** the Learn screen to list the exercises that will really be built, in their final steps
**So that** I am not shown items that will never come

### US-08: Lasting exam results
**As a** learner
**I want** each word I am examined on to keep its known / repeat result on my phone
**So that** I can later repeat just the words I do not know yet

## 5. Acceptance criteria

### Learn list and opening an exercise

### AC-01 (US-07) — happy path
**Given** the app after this feature
**When** the learner opens the learn page
**Then** it lists thirteen exercises in plan order: Step 1 — Mnemonic story, Dialogs from movie, Match synonyms, Match word and definition, Guess my word, Pick the right answer; Step 2 — Fill the gaps, Remember or not, Sentence patterns; Step 3 — Make your own sentences, Translate sentences, Explain it to a friend, Quiz. Every exercise except the two built ones shows "Coming soon" and cannot be ticked, and the web learn page lists the same thirteen in the same steps and order.

### AC-02 (US-07) — cross-context
**Given** a partner holds an old web learn link that names Match antonyms, or a removed Speak mode, as an exercise or as a pick
**When** the partner opens it
**Then** an exercise address answers with the same "gone" page as any unknown exercise, and a pick naming it is ignored while the rest of the page shows normally.

### AC-03 (US-01) — happy path
**Given** an exercise that is available and has its screen built, a selected word group, and that exercise ticked (alone or with others)
**When** the learner presses Start
**Then** that exercise opens for the selected word group of the session the learn page shows; with several ticked they open one after another in list order as today, and Back from the last returns to the learn page with the ticks kept.

### AC-04 (US-01) — domain invariant
**Given** an exercise marked available whose screen is not built (a release mistake)
**When** the learner starts it
**Then** the coming-soon screen opens; the app never shows an empty or broken screen, and an exercise that is not available still cannot be ticked.

### AC-05 (US-01) — cross-context
**Given** the learn page was opened for a History session
**When** the learner starts an exercise
**Then** the exercise uses that session's word group and words, and changes none of its word rows, groups or dialogues (word results, AC-35, are the only thing written).

### Exercise frame

### AC-06 (US-02) — happy path
**Given** an exercise that needs data before its first round
**When** it opens
**Then** a loading indicator shows until the data is ready, then round 1 shows; after each round a summary lists every word of that round with its result, offering "Next round" while rounds remain and "Done" after the last, which returns to the learn page.

### AC-07 (US-02) — error
**Given** the data for an exercise cannot be loaded (offline, no answer within the time limit, or a server failure)
**When** the exercise opens
**Then** one error line and a Retry button show and no round starts; Retry loads again, and when it succeeds round 1 shows with all usable words (never a partial round).

### AC-08 (US-02) — domain invariant
**Given** a word group with fewer usable words than the exercise's smallest round (after words without data are left out)
**When** the exercise opens
**Then** a "not enough words" message (the exercise's own text, else "Not enough words for this exercise") and a Back button show, and nothing else.

### AC-09 (US-02) — domain invariant
**Given** an exercise with a round size of at least m and at most M words (M at least 2m − 1)
**When** its usable words are split into rounds
**Then** the rounds keep word order, use the fewest rounds that fit, differ in size by at most one word and are never smaller than m. For example, 7 words at 3–6 give 4 + 3, 13 words at 3–9 give 7 + 6, 2 words at 3–6 give no round (AC-08), and the same input always gives the same split.

### AC-10 (US-02) — happy path
**Given** a round in progress
**When** the learner leaves with Back
**Then** the learn page shows again with no summary; opening the exercise again starts at round 1 with fresh data from the cache, and nothing about the left round is kept except word results already final (AC-35).

### Typed and choice answers

### AC-11 (US-03) — happy path
**Given** the stored word "the cat", "to run" or "Ice cream"
**When** the learner types "Cat", "run" or "ice  cream " (any case, extra spaces, with or without a leading "to", "a", "an" or "the" on either side)
**Then** the answer is right.

### AC-12 (US-03) — error
**Given** the stored word "receive"
**When** the learner types "recieve" (one swap of neighbours, word of five or more letters)
**Then** it counts as right with the mark "almost" and the correct spelling is shown; "cta" for "cat" (under five letters), "walked" for "walk" (another form) and "recive" for "receipt" (two edits) are wrong.

### AC-13 (US-03) — happy path
**Given** a typed question
**When** it shows
**Then** the keyboard opens at once with autocorrect and suggestions off, the keyboard's Send key submits, and an empty answer is not submitted.

### AC-14 (US-03) — domain invariant
**Given** a typed question in a practice exercise (Step 1–2)
**When** the learner's first answer is wrong
**Then** the first letter and the letter count show, one more try is allowed and after it the answer shows; "Show answer" ends the word as missed. In an exam (Step 3) the same question gives no hint, no second try and no "Show answer", only Skip, which counts as repeat.

### AC-15 (US-03) — domain invariant
**Given** a definition, clue or example sentence that contains the word being asked, as a whole word in any case or with the ending -s, -es, -ed or -ing, or a phrase word in order
**When** it is shown on a card
**Then** each such place shows as "___"; the word inside another word (cat in "category") is not touched, and a text that should hold the word exactly once but holds it twice or not at all is rejected for that word.

### AC-16 (US-05) — happy path
**Given** an AI-written sentence for a word
**When** it is shown
**Then** every whole-word place of the word (same rule as AC-15) is bold and nothing else is; any markup characters the text carries are shown as plain characters, never as formatting.

### AC-17 (US-03) — happy path
**Given** a word with a translation and at least three other words with distinct translations
**When** a choice question is made for it
**Then** "word → translations" shows the English word and four distinct translations, and "meaning → words" shows its stored definition (else its translation) with the word masked (AC-15) and four distinct English words; exactly one option is right.

### AC-18 (US-03) — domain invariant
**Given** candidate wrong options
**When** a choice question is made
**Then** no option equals the right one or another option (ignoring case and spaces), words without a translation are never used as translation options, the group's own words are used before the session's other words, and a word for which four distinct options cannot be found gets no question (it is left out of the round, never shown with fewer options).

### AC-19 (US-03) — domain invariant
**Given** the same word, the same candidate words, the same kind and the same random seed
**When** a choice question is made twice
**Then** both questions are identical (prompt, options, their order and the right one).

### Exercise data

### AC-20 (US-04) — happy path
**Given** a word group of 10 words, none asked before, and an exercise that needs one kind of data (synonym, definition, clues, sentence, pattern or translation prompt)
**When** the exercise loads
**Then** one AI request answers all 10 words in the sense of each word's translation (for "bank" with "берег", a river-bank synonym or definition), and a word the AI has no answer for ("none") is left out of the rounds.

### AC-21 (US-04) — happy path
**Given** the same word with the same translation was answered for the same kind within the last 30 days, in any session
**When** an exercise asks for it again
**Then** the same answer comes back without a new AI request and without using the day's allowance; if every word of the group is answered this way, nothing is charged at all.

### AC-22 (US-04) — domain invariant
**Given** a word whose translation the learner changed since its data was made
**When** the exercise asks for it
**Then** the old answer is not reused: new data is made for the new translation's sense.

### AC-23 (US-04) — error
**Given** a data request that has no words, more than 19 words, an unknown kind, a word id used twice, an empty word, a word over 100 characters or a translation over two hundred characters
**When** it reaches the server
**Then** it is refused with a plain reason, nothing is generated and nothing is charged; the app shows the error line with Retry (AC-07).

### AC-24 (US-04) — error
**Given** the AI fails, does not answer within the time limit, or answers with something that cannot be read
**When** the exercise loads
**Then** the learner sees the error line with Retry (AC-07); nothing from that answer is cached, and the allowance unit taken for the attempt is not given back.

### AC-25 (US-04) — domain invariant
**Given** one word's answer breaks its kind's rule (a synonym equal to the word, a sentence without the word or with it twice, a pattern that spells the word, a translation prompt that contains the English word or whose bold cue is not part of it, a text over its length limit)
**When** the answers are returned
**Then** that word comes back as "no answer" and is not cached (it is asked again next time), while the other words come back normally.

### AC-26 (US-06) — authorization
**Given** a caller without the app's secret — a partner on the shared page, a browser or a script
**When** it asks for exercise data or a sentence check
**Then** it is refused like every other app-only service, nothing is generated and no allowance is used; neither service is reachable from the shared page or the web learn page.

### AC-27 (US-06) — domain invariant
**Given** two hundred AI data requests have been made today (UTC) across the whole app
**When** an exercise needs data that is not cached
**Then** the request is refused and the learner sees "Today's exercise limit is reached. Try again tomorrow." with Back; a request fully answered from the cache is still served, and the story allowance is not touched.

### Sentence check

### AC-28 (US-05) — happy path
**Given** a word, its translation, a task (pattern, own, translate or explain) and a learner's sentence that uses the word correctly with no error
**When** the learner sends it
**Then** within the time limit the result line shows "Good".

### AC-29 (US-05) — happy path
**Given** a learner's sentence with a grammar or spelling error, or one that misses the task
**When** it is checked
**Then** the result line shows one corrected sentence that keeps the learner's meaning and one note of at most 100 characters in plain English.

### AC-30 (US-05) — error
**Given** an empty answer, a one-word answer, or an answer over two hundred characters (over three hundred for an explanation)
**When** the learner taps Send
**Then** nothing is sent and the exercise shows "Write a full sentence" (or "Keep it under two hundred characters"); the server refuses the same input if it ever arrives.

### AC-31 (US-05) — domain invariant
**Given** the AI marks a sentence correct but the sentence does not contain the word by the app's matching rule (AC-15; a synonym instead of the word)
**When** the result is decided
**Then** the result is "fixed", not "Good", and the note reads "Use “<word>” in your sentence."; and a sentence with "walked" for "walk" counts as using the word even if the AI says it does not.

### AC-32 (US-05) — domain invariant
**Given** the AI marks a sentence not correct but its corrected sentence equals the learner's (ignoring case, outer spaces and end punctuation)
**When** the result is decided
**Then** the result is "Good", and no fix or note is shown.

### AC-33 (US-05) — domain invariant
**Given** the task "explain" and an explanation that contains the word in any form
**When** it is checked
**Then** the result is never "Good", whatever the AI says; grammar and spelling are not judged and no corrected sentence is shown.

### AC-34 (US-05) — error
**Given** the check does not answer within 15 seconds, the phone is offline, or the server fails
**When** the learner sends a sentence
**Then** an error line with Retry shows, the typed text stays unchanged and is not counted as a try; Retry sends the same text again, and a word never checked gets no result.

### AC-34b (US-06) — domain invariant
**Given** five hundred sentence checks have been made today (UTC) across the whole app, or the same learner sentence was checked a minute ago
**When** another check is sent
**Then** with the day used up it is refused with "Today's exercise limit is reached. Try again tomorrow." and the text stays; without that, the repeated sentence is checked again (checks are never reused), and counts again.

### AC-34c (US-06) — cross-context
**Given** the phone has made more app requests in the last minute than the per-device limit every app service shares (stories, grouping, data, checks)
**When** an exercise asks for data or a check
**Then** the request is refused, the learner sees "Too many requests. Wait a moment and try again." with Retry, and no allowance is used.

### Word results

### AC-35 (US-08) — happy path
**Given** a Step 3 exam on a session
**When** a word's result becomes final (known or repeat, by D-32)
**Then** the result is saved on that session at once with the word, the exercise and the time; leaving the exam later keeps it, and the word's current result is its most recent one from any exam.

### AC-36 (US-08) — domain invariant
**Given** a word that was never examined, or an exam left by error or Back before the word's result was final, or a self-rated or Step 1–2 exercise
**When** results are read
**Then** that word has no result from it (no label at all, never "repeat").

### AC-37 (US-08) — cross-context
**Given** a session with saved word results
**When** the learner shares, publishes, exports (any of the five formats) or copies its words, or the lightning icons are shown
**Then** none of them contains or reacts to the results, the session's last-changed time and History order do not move because of a result, and results whose word row was deleted are ignored.

### AC-38 (US-08) — domain invariant
**Given** a session saved before this feature
**When** the app opens it after the update
**Then** it opens unchanged with no results; and a session holding the most results allowed (2000) drops its oldest result when a new one is saved.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Exercise data, all words cached, p95 (server) | ≤ 500 ms | Worker log `learn data` line, `ms` field, misses = 0 |
| Exercise data, 19 words uncached, p95 (server) | ≤ 15 s; server gives up at 25 s, app at 30 s | Worker log `ms`, misses > 0 |
| Sentence check p95 (server) | ≤ 6 s; server gives up at 12 s, app at 15 s (D-25) | Worker log `learn check` line, `ms` field |
| AI cost per uncached data request (19 words, clues) | ≤ $0.01 | token usage in the log × fixed AI list price |
| AI cost per sentence check | ≤ $0.002 | same |
| Worst-case exercise AI spend per UTC day, app-wide | ≤ $3 (200 data × $0.01 + 500 checks × $0.002) | the two day counters |
| Data cache lifetime | 30 days per word + translation + kind | store TTL |
| Determinism of kit helpers | same input + seed → same output, 100% | unit tests |
| Kit helper test coverage | every rule in AC-09, AC-11–AC-19, AC-31–AC-33 has a unit test; no widget or network needed | `tool/test.sh changed` |
| Worker test coverage | every AC-20–AC-34c branch with a stubbed AI | `vocab-photo-api` node tests |
| Session growth from results | ≤ 2000 results per session (about 100 KB) | store cap |

### 6.1 Security / privacy

- **Data classification:** internal. The learner's words, translations and sentences are personal learning content, not regulated data.
- **Personal data touched:** learner sentences and explanations are sent to the fixed AI for one check and never stored on the server or written to logs. Words and translations are cached on the server by a one-way key, with the AI's answer as the value (no session id, no address). Word results stay on the phone only.
- **AuthZ/AuthN impact:** both new services are app-only behind the shared app secret and the per-device rate limiter, like the story services. No new public capability; the web learn page gains none.
- **Abuse cases:**
  - Leaked app secret used to generate data in bulk: the day allowance (200 AI calls) caps cost; cache hits are free but cost the attacker nothing either.
  - Leaked secret used to spam checks: the day allowance (500) plus the per-device limiter (20 a minute).
  - Prompt injection through a word, translation or sentence: inputs are sent as JSON data in the user turn with fixed instructions; the reply is parsed strictly per kind and length-checked; an answer that breaks the rules is dropped (AC-25).
  - Poisoning the shared cache with odd translations: a key covers word + translation, so a bad entry only affects that exact pair; entries expire in 30 days and can be purged by dropping the separate store (§6.2).
  - Partner on the shared page: no route; refused like any app-only service (AC-26).
- **Security review:** Required (new paid AI surfaces, a server-side cache shared across learners).

### 6.2 Deployment (owner, local Worker work only)

The agent builds and tests the Worker locally; the owner creates the bindings and deploys:
1. **Create one KV namespace** `vocab-learn-data` and bind it as `LEARN_DATA` in `vocab-photo-api/wrangler.jsonc` (the owner fills in the id). *Implementation note:* `wrangler.jsonc` already declares `LEARN_DATA` with the placeholder id `00000000000000000000000000000000` (`wrangler dev` and the tests simulate it with any id); replace it with the id `npx wrangler kv namespace create vocab-learn-data` prints. It holds only the exercise data cache, so it can be purged without touching `DEFINITIONS` or `SESSIONS`. Without the binding the data service answers "not available" and the exercise shows the error line.
2. **No new D1 database:** apply migration `0006_learn_allowance.sql` to the existing `vocab-sessions` (`DB` binding) with `wrangler d1 migrations apply vocab-sessions --remote`.
3. **No new secret:** the fixed exercise AI uses the existing `ANTHROPIC_API_KEY`.
4. **No new rate limiter:** the existing `RATE_LIMITER` (20 requests / 60 s per address) applies.

## 7. Metrics / KPIs

- **Cache hit rate of exercise data (words served from the cache ÷ words asked)** — baseline: 0 (new). Target: ≥ 60% within 30 days of the first data exercise shipping.
- **Data request failure rate (error line shown ÷ data loads)** — baseline: 0. Target: ≤ 3% per week once Wave 1 ships.
- **Sentence check failure rate (error line ÷ checks sent)** — baseline: 0. Target: ≤ 2% per week once Wave 2 ships.
- **Guard rate (AC-31 or AC-32 overrode the AI ÷ checks)** — baseline: TBD. The Worker logs the AI's raw `ok` and `usesWord`; the app logs its verdict in debug builds. Target: ≤ 5%, otherwise tune the prompts.
- **Frame reuse** — baseline: 0 exercises. Target: all exercises of Waves 0–3 use the shared frame, and none has its own loading, error or summary code (checked at each exercise's review).
- **Daily allowance hits (days a counter reached its limit)** — baseline: 0. Target: 0 per month in normal use; one hit means review the caps.

## 8. Open questions

- [ ] Does "implement all exercises" (2026-10-14) also undo the cancellations of H-06/H-08 (match-antonyms, chain-story, the two Speak modes)? Default now: no; the thirteen-item list of AC-01 stands. — owner: Maksym, due: before the registry task of `sdd:tasks`.
- [ ] Should the Learn rows show the subtitles of `learn-screen-briefs.md` instead of "Coming soon"? That is a visible change plus a new field on the approved Exercise model. Default now: no; names only, "Coming soon" kept. — owner: Maksym, due: before pick-the-answer ships.
- [ ] CLAUDE.md approval lists: rule 5 should name `WordResult` (and `Session.results`), rule 3 the Learn list change of this feature. Only the owner edits CLAUDE.md. Default now: this spec's ¶4 records the decisions. — owner: Maksym, due: before `sdd:implement learn-kit`.
- [ ] Confirm the daily caps (200 data calls, 500 checks, worst case about $3 a day). Default now: as stated (H-02, H-03; no owner needed). — owner: Maksym, due: first deploy.

## Implementation status

Implemented 2026-10-14 on `feat/learn-exercises` (commits `feat(learn-kit): …`), test-first. All 40 ACs have code; ACs that describe an exercise's own flow (AC-03 order of several exercises, AC-10 Back mid-round, AC-35 an exam writing a result) are served by the kit and become testable end to end with the first exercise that uses them.

**Done.** Worker: `POST /learn/data` (`src/learn/data.ts`, prompts in `src/learn/prompts.ts`), `POST /learn/check` (`src/learn/check.ts`), day caps (`src/learn/allowance.ts`, migration `0006_learn_allowance.sql` + `down/`), the 13-item list (`exercises.json`); tests `learn-data`, `learn-check`, `learn-allowance`, `learn`, `learn-exercises` (`.test.mjs`), with the Anthropic stub extended for both routes. App: `WordResult` + `Session.results` + `SessionStore.appendResult`, `ExamResultSink`, `LearnApiService`, `ExerciseRoute` + `exerciseScreen`, the kit in `lib/features/learn/kit/`; tests `word_result`, `learn_kit_helpers`, `learn_kit_widgets`, `learn_api_service`, `exercise_route`, `learn_exercises` (`_test.dart`). No exercise is available yet: every new id shows "Coming soon", and `exerciseScreen` sends every id to the coming-soon screen until its exercise adds a `case`.

**Deviations from S-01..S-24 (shapes widened, names kept).**
- `LearnDataKind` is a typed const class (`LearnDataKind<T>`, `.synonym` … `.translate`, `.values`, `.wire`), not an enum, so `fetchData(LearnDataKind.synonym, words)` returns `Map<String, SynonymData?>`. The per-kind answers are Dart records (`SynonymData`, `DefinitionData`, `CluesData`, `SentenceData`, `PatternData`, `TranslateData`); `LearnWord`, `LearnCheckRequest`, `CheckReply` are record typedefs; `LearnCheckTask` is an enum.
- `CheckVerdict` is sealed: `CheckRight` / `CheckFixed(fixed, note)`, because S-21's note override has to travel with the verdict.
- `ExerciseScaffold` also takes `title` (top bar) and `onNextRound`; `TypedAnswerField` also takes `expected` and calls `onSubmit` once with a `TypedAnswerResult` (match, answer, firstTry, gaveUp).
- `matchTyped`: an answer that is the word plus -s/-es/-ed/-ing/-d is wrong even when it is one edit away ("receives" for "receive"), per D-18's "other forms are wrong".
- `SessionStore.put` keeps the stored `results` (results are written only by `appendResult`), so the words notifier's older copy of the session cannot wipe them. `ExamResultSink.record` with a null session id writes to the store's current-session pointer.
- The learn page's Start decision moved, unchanged, into a top-level `startRouteFor` in `learn_screen.dart` so it can be tested without an available exercise.
- Copy the spec does not give, chosen here: the check failure line "Could not check the sentence. Check the connection and try again." (AC-34); "Keep it under three hundred characters" for an explanation (AC-30); the practice hint "Starts with “r”, 7 letters", and "Almost: <word>" / "Answer: <word>" (AC-12, AC-14). The exercise specs may replace them.
- A pattern (S-15) must hold at least one slot. A data request is validated before the binding check (400 before 503).
- Not done: §7's "the app logs its verdict in debug builds" (no logging was added to the pure `judgeCheck`).
- Worker plumbing: `LEARN_AI_TIMEOUT_MS` is a test-only override (set to 1 s in `scripts/test.mjs`); `src/define.ts` now imports `./http.ts` with its extension so the Node tests can load `data.ts`.

**Owner deploy steps.**
1. `cd vocab-photo-api && npx wrangler kv namespace create vocab-learn-data`, then paste the printed id into the `LEARN_DATA` entry of `wrangler.jsonc` (replacing `00000000000000000000000000000000`).
2. `npx wrangler d1 migrations apply vocab-sessions --remote` (applies `0006_learn_allowance.sql`: tables `all_learn_data`, `all_learn_checks`).
3. No new secret (the existing `ANTHROPIC_API_KEY`), no new rate limiter. Run `npm run test:full`, then deploy.

