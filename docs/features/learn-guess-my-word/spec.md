---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-15"
feature_size: "S"
---

# Spec — learn-guess-my-word

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-fill-the-gaps CONTEXT](../learn-fill-the-gaps/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/guess-my-word.md`](../learn-exercises/guess-my-word.md) (the clarified small spec — the starting point), [`learn-exercises/fable-ideas.md`](../learn-exercises/fable-ideas.md) §1, [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-02, H-07, H-08, H-09, Wave 2 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-03..D-06, D-08, D-09, D-11..D-13, S-01..S-50; this spec adds S-51, S-52), "Implementation status" of [`learn-kit/spec.md`](../learn-kit/spec.md) and [`learn-match-synonyms/spec.md`](../learn-match-synonyms/spec.md), kit code in `lib/features/learn/kit/` (`exercise_phase.dart`, `exercise_scaffold.dart`, `result_summary.dart`, `split_rounds.dart`, `word_marks.dart`, `definition_text.dart` (`definitionCard`), `exercise_random.dart`, `exercise_words.dart`, `match_board.dart` (`MatchCard`, for the look only)), `lib/features/learn/match_definitions/`, `lib/core/dialogues/dialogue_match.dart` (`matchPlaces`), `lib/core/services/learn_api_service.dart` (kind `clues`, `CluesData`), `vocab-photo-api/src/learn/data.ts` and `prompts.ts` (kind `clues`). House style: [`learn-sentence-patterns/spec.md`](../learn-sentence-patterns/spec.md).

## 1. Context

The learner has a word group selected on the learn page and wants to meet its words again in a way that is neither a translation nor a definition match. Guess my word is a riddle: the screen shows one short English clue and a grid of the round's words; the learner taps the word the clue describes. A wrong tap greys that word out and shows a closer clue; three clues in all, the last almost a giveaway. Finding the word on clue 1 scores 3, on clue 2 scores 2, on clue 3 scores 1; a wrong tap after clue 3 scores 0 and shows the answer. Each clue is another encoding of the word (a situation, a collocation, a description), and the "almost got it" moment is retrieval effort. A summary lists each word's score.

Why now: `hard-decisions.md` Wave 2 schedules guess-my-word after sentence-patterns. Everything it needs exists: the Worker's kind `clues` (three strings, each ≤120 characters, S-15) behind the one data call per group with its cache and day cap (H-02, S-14..S-19), the app service's `CluesData`, and the kit frame, rounds, masking and stored-definition line (S-06, S-07, S-12, S-40). Only the screen is missing. H-08 keeps the exercise because graded clues are a mechanic no other exercise has.

Committed approach: one `@riverpod` notifier plus one round body on top of the kit (S-30). On open the notifier reads the group's words (`exerciseWordsProvider`, S-08), asks the Worker once for kind `clues` for the candidates, builds each word's three shown clues (S-51), drops words without three usable clues, splits rounds of 3 to 9 (D-13), and for each round shuffles the grid and the target order once with the kit's `Random` (S-27, S-34). The round body shows the clues so far, the grid, and the outcome of the current target; the notifier keeps the clue level, the greyed words, the found words and the scores (S-52). Results are summary-only (D-04, D-12). No Worker change.

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- **Clue 3 is the stored definition when there is one (S-51, H-09, S-40, S-42).** H-09 says "clue 3 of guess-my-word is the same text" as the definition exercises use. So clue 3 = the kit's `definitionCard(stored definition, word)` (definition line, masked, cut to 120 characters) when it is non-null; else the Worker's clue 3. Clues 1 and 2 always come from the Worker, so the Worker is asked for every candidate (one call) and no kind `definition` call is made. The learner's chosen sense wins where it exists.
- **Every clue is masked by the app (D-08, S-12).** The Worker prompt already says "never the word itself", but the Worker does not check it. The app shows every clue through `maskWord`: the word, and its -s/-es/-ed/-ing forms, in any case, become "___". A clue that is nothing but "___" and punctuation after masking is not usable; a word that does not get three usable clues is left out (clue 3 falls back to the Worker's when the stored one is unusable). Irregular forms ("ran" for "run") are not caught by the shared matching rule; this is accepted, not fixed here (§8).
- **No Worker change.** The kind `clues` prompt and checks are used as built (graded, ≤120 characters, sense of the translation, "none" allowed). "Simple English, one sentence each" from the small spec is not enforced by a check; the KPI in §7 watches it. Changing the prompt would need a cache key bump (S-16).
- **Candidates need a translation (as S-50).** The Worker's sense comes from the translation (D-06) and a long press on a grid word shows it, so a word to learn with an empty trimmed word, translation or row id is not a candidate and is never sent. Two candidates with the same word (trimmed, lower case, inner spaces collapsed) would be two equal grid tiles; only the earlier in group order stays (as S-38).
- **Fewer than 3 candidates → "Not enough words for this exercise" with no Worker call** (as S-39, S-50). Fewer than 3 usable words after the clues → "Not enough words with clues for this group" (the small spec's line).
- **The round (S-52).** Rounds: `splitRounds(usable, min: 3, max: 9)` in group order; within a round the grid order and the target order are two separate shuffles from the kit's `Random`, made once when the exercise opens. A found word stays marked and does nothing when tapped; greyed words come back for the next target. The last target of a round is often found by elimination; this is accepted (the small spec keeps found words out of the targets).
- **After a target ends.** A right tap marks the word found with its points, and about 600 ms later the next target's clue 1 shows (taps are ignored meanwhile), so the learner sees the lock first, like the match board's last lock (S-36). A wrong tap on clue 3 reveals the answer: the target is marked as missed in the grid, the line "The word was “<word>”." shows, and a "Next" button moves on — the learner gets time to read the answer.
- **Long press shows the translation** of a grid word in a tooltip-style popup and changes nothing else (small spec); clues have no long press.
- **Copy chosen here:** title "Guess my word", counter "Word n of m" (m = round size), prefixed by "Round r of k · " when k ≥ 2, instruction "Tap the word the clues describe.", clue lines "Clue 1", "Clue 2", "Clue 3", result lines "Right: 3 points" / "Right: 2 points" / "Right: 1 point", "The word was “<word>”.", button "Next", summary results "3 points" / "2 points" / "1 point" / "Not found", summary heading "Score: s of t" (t = 3 × round size, S-33). Frame lines are the kit's (S-06).
- **Files:** `lib/features/learn/guess_my_word/` (`guess_my_word_notifier.dart`, `guess_my_word_screen.dart`; the grid widget lives here, S-05, one user), `case 'guess-my-word'` in `exerciseScreen`; `available: true` in `exercises.json` (Worker) and `exercises.dart` (S-02). No kit file changes; `definitionCard`, `maskWord`, `splitRounds`, `ExerciseScaffold`, `ResultSummary` are used unchanged.
- **People (D-11, H-07):** no shared-page buzzer and no people-written clues in v1; no write-back is built.

## 2. Goals

- The learner can meet every word of the selected group that has a translation as a three-step riddle, scored by how early they recognise it.
- A clue never gives its own word away, and every round ends: a word is found or shown, never guessed forever.
- The exercise costs at most one Worker data call per open and nothing on a repeat open of the same group within the cache time.

## 3. Non-goals

- No saved results and no change to any word (D-04, D-12); scores are never a Step 3 result (no `ExamResultSink` write).
- No shared-page buzzer, no people-written clues, no play on the web learn page (D-11, H-07).
- No Worker change: no new prompt rule, no clue check for "one sentence" or for irregular forms of the word (§1, §8).
- No typed answer and no hint other than the next clue and the long-press translation.
- No clue read aloud and no speaker (the small spec names none; D-22 would show it only after the reveal).

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Guess my word in Step 1 and press Start with a word group selected
**So that** I play exactly that group's words

### US-02: Guess a word from graded clues
**As a** learner
**I want** one clue at a time and a grid of the round's words to tap, with a closer clue after each wrong tap
**So that** I recognise the word from its meaning, with help only when I need it

### US-03: Score by how early I knew it
**As a** learner
**I want** 3, 2 or 1 points for finding a word on clue 1, 2 or 3, and the answer shown after a wrong tap on clue 3
**So that** I see how well I know each word and never get stuck

### US-04: Clues that never give the word away
**As a** learner
**I want** the word itself hidden as "___" in every clue, and words without good clues left out
**So that** the riddle is fair

### US-05: See my round results
**As a** learner
**I want** a summary after each round with each word's score and the round total
**So that** I know which words need more practice

### US-06: Clear stop when the group cannot be played
**As a** learner
**I want** a plain message when the group has too few words with clues or the clues cannot be loaded
**So that** I am never left on an empty or broken round

### US-07: Play any session without changing it
**As a** learner
**I want** to play a group of the current session or of a History session
**So that** old sessions are useful too, and playing never changes my words

## 5. Acceptance criteria

### Opening and the round

### AC-01 (US-01) — happy path
**Given** the app after this feature and a selected word group of 6 words to learn, each with a translation, and a Worker that has clues for each
**When** the learner opens the learn page, ticks "Guess my word" in Step 1 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens with the title "Guess my word", shows "Word 1 of 6", the line "Tap the word the clues describe.", the first target's "Clue 1" with its text, and a grid of the 6 words as English words, three per row; no clue 2 or 3 is shown yet.

### AC-02 (US-02) — domain invariant
**Given** a round of 6 words and a fixed random source
**When** the round opens, and again when the exercise is reopened with the same random source
**Then** the grid holds exactly the round's 6 words, each once, in a shuffled order; every word is the target exactly once, in a random order made once for the round; with the same random source both orders are the same every time.

### AC-03 (US-03) — happy path
**Given** the target shows clue 1
**When** the learner taps the target in the grid
**Then** the word is marked found with "Right: 3 points"; taps do nothing for about 600 ms; then the next target shows "Word 2 of 6" and its clue 1, with no greyed word in the grid.

### AC-04 (US-02) — happy path
**Given** the target shows clue 1
**When** the learner taps another, not found word
**Then** that word greys out and cannot be tapped for this target, and "Clue 2" shows under clue 1 for the same target; no points are given yet.

### AC-05 (US-03) — happy path
**Given** clue 2 shows after one wrong tap
**When** the learner taps the target
**Then** the word is marked found with "Right: 2 points"; after one more wrong tap and a right tap on clue 3 it is "Right: 1 point" instead.

### AC-06 (US-03) — domain invariant
**Given** clue 3 shows after two wrong taps
**When** the learner taps a third wrong word
**Then** that word greys out, the target scores 0, the target is marked in the grid as the answer, the line "The word was “<word>”." and a "Next" button show, and no other tap changes anything; Next shows the next target's clue 1 (or the summary after the last target).

### AC-07 (US-02) — domain invariant
**Given** two targets are found and the third target shows
**When** the learner taps a found word, or a word greyed for an earlier target
**Then** the found word does nothing (no wrong tap, no clue change); a word greyed for an earlier target is tappable again, because greyed words come back for each new target. When every other word is found or greyed, the target is the only word left to tap (the last target of a round, or clue 3 of a small round), and a wrong tap after clue 3 cannot happen.

### AC-08 (US-02) — happy path
**Given** any grid word
**When** the learner long-presses it
**Then** its translation shows in a small popup and nothing else changes (no guess, no grey, no clue); a long press on a clue shows nothing.

### Clues

### AC-09 (US-04) — domain invariant
**Given** the Worker's clue 2 for "walk" is "You walk the dog; Walking is good for you."
**When** the clue shows
**Then** it reads "You ___ the dog; ___ is good for you."; every whole-word place of the word and its -s, -es, -ed or -ing forms, in any letter case, is "___", and a word inside another word ("sidewalk") stays as it is.

### AC-10 (US-04) — domain invariant
**Given** a word to learn whose stored definition reads "definition: a place where you keep money\nexample: I went to the bank."
**When** its clue 3 shows
**Then** clue 3 is "a place where you keep money" (the definition line, masked, at most 120 characters, cut at its first sentence else at a whole word plus "…"); clues 1 and 2 are the Worker's; a word with no stored definition gets the Worker's clue 3.

### AC-11 (US-04) — error
**Given** a word whose Worker clue would be only the word itself ("Walk.") after masking ("___.")
**When** the exercise opens
**Then** that word is left out (no grid tile, not a target, not in the summary); when only the stored definition is unusable that way, the Worker's clue 3 is used instead and the word stays.

### AC-12 (US-04) — error
**Given** a word for which the Worker answers "none", or an answer it refused (not three clues, or a clue over 120 characters)
**When** the exercise opens
**Then** that word is left out of every round; the other words play normally.

### AC-13 (US-02) — domain invariant
**Given** any clue
**When** it shows
**Then** it is plain text (stars and other markup characters show as they are), it wraps and is never cut on screen, and earlier clues of the same target stay visible above it in order "Clue 1", "Clue 2", "Clue 3".

### Where the data comes from

### AC-14 (US-02) — cross-context
**Given** a group of 7 words to learn, 6 with a translation and one with an empty translation
**When** the exercise opens
**Then** the Worker is asked once for clues for exactly the 6 words, each with its translation, while the frame's loading state shows; the word without a translation is never sent and is not in the grid; the same group opened again within 30 days takes nothing from the daily data allowance.

### AC-15 (US-04) — domain invariant
**Given** a group holding "light" twice (as "світло" and as "легкий")
**When** the exercise opens
**Then** only the earlier "light" in group order is a candidate; the grid never shows two equal words.

### Rounds, empty and error states

### AC-16 (US-05) — domain invariant
**Given** 12 usable words
**When** the rounds are built
**Then** there are two rounds of 6 in group order; 19 give 7 + 6 + 6, 9 give one round of 9, 10 give 5 + 5, 3 give one round of 3; never a round under 3; when there are two or more rounds the counter reads "Round 1 of 2 · Word 1 of 6".

### AC-17 (US-06) — error
**Given** a selected group with fewer than 3 words to learn that have a word and a translation
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked.

### AC-18 (US-06) — error
**Given** a selected group with 3 or more candidates, of which fewer than 3 get three usable clues
**When** the learner starts the exercise
**Then** only "Not enough words with clues for this group" and "Back" show, no round starts, and Back returns to the learn page.

### AC-19 (US-06) — error
**Given** the phone is offline (or the Worker fails, times out or has no exercise storage) while the clues load
**When** the exercise opens
**Then** only "Could not load the exercise. Check the connection and try again." and "Retry" show, with no partial round; back online, Retry loads the clues and the first target shows.

### AC-20 (US-06) — cross-context
**Given** the Worker's daily allowance for exercise data is used up and a needed clue is not in its cache
**When** the exercise opens
**Then** only "Today's exercise limit is reached. Try again tomorrow." and "Back" show (no Retry); when the Worker answers that requests are too frequent, "Too many requests. Wait a moment and try again." and "Retry" show instead.

### Summary, sessions and people

### AC-21 (US-05) — happy path
**Given** a round of 4 words that ended with 3, 2, 1 and 0 points
**When** the last target ends (after the 600 ms pause for a right tap, or after Next for a revealed answer)
**Then** the summary shows the heading "Score: 6 of 12" and lists the words in group order as "3 points", "2 points", "1 point", "Not found"; "Next round" while rounds remain, "Done" after the last; Done returns to the learn page (or opens the next ticked exercise, as today).

### AC-22 (US-05) — happy path
**Given** the summary of round 1 of 2
**When** the learner taps "Next round"
**Then** round 2 opens with its own shuffled grid of only its words, "Word 1 of n" and the first target's clue 1, with no found or greyed word.

### AC-23 (US-07) — domain invariant
**Given** a round in progress or finished
**When** the learner leaves with Back or Done
**Then** nothing is kept: no score, no word result, no change to any word, translation, definition, group or session; reopening starts at round 1 with clue 1; a Worker answer arriving after leaving changes nothing and causes no error.

### AC-24 (US-07) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner plays the exercise to the end
**Then** only that session's words are used and sent (with their translations), clue 3 uses that session's stored definitions, and the History session is unchanged afterwards (same words, groups and last-changed time).

### AC-25 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 1
**Then** Guess my word is listed with the same name and step as in the app and cannot be played there; there is no buzzer and no way to add a clue; only the learner, in the app, can play it (the Worker's exercise data is behind the app's secret).

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per load Retry) | 0 when the group has fewer than 3 candidates; else exactly 1 data call holding only the candidates; 0 calls during a round, on Next, Next round or the summary | widget test with a counting `learnApiService` fake |
| Day-cap cost of a repeat open | 0 data units (all cache hits) | existing Worker test (all-hit request takes none, S-18) |
| Tap to feedback (grey + next clue, or found mark) | ≤ 100 ms | widget test pumps one frame |
| Start to first clue, cached group, good network | ≤ 1.5 s | manual check before ship |
| Masking | 0 shown clues holding the word or its -s/-es/-ed/-ing forms as a whole word | unit test over S-51 with the shared matching cases |
| Determinism | same words + same seed → same rounds, grid order and target order, 100% | notifier test over 1000 seeds with `exerciseRandomProvider` overridden |
| Kit reuse | 0 changed lines in `lib/features/learn/kit/` and in the Worker's `src/learn/` code (only the exercise list flips) | `git diff` at `sdd:review` |
| Test coverage | every AC has a unit or widget test; AC-25 by the Worker learn-page test | `tool/test.sh changed` |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, translations and definitions.
- **Personal data touched:** none new. Words and translations go to the Worker as S-14 already allows; nothing is stored in the app; the Worker caches clues per word and translation only (S-16).
- **AuthZ/AuthN impact:** none new. The data route is behind the app's secret (S-14); no play surface on the web.
- **Abuse cases:**
  - Partner tries to play or add a clue from a web link: the web learn page lists the exercise only; no write-back exists (AC-25, D-11).
  - Repeated opens draining the AI budget: one call per open, cache hits are free, the daily data cap and the per-device limiter apply (AC-14, AC-20, S-18).
  - A word or translation that tries to instruct the AI: the prompt treats them as data (S-17); the worst case is a bad clue, which is masked and shown as plain text in one practice round that saves nothing.
  - AI text with the word in it, markup or great length: masked (AC-09), plain text (AC-13), refused over 120 characters by the Worker (AC-12).
- **Security review:** N/A — no new data flow, route, secret or storage.

## 7. Metrics / KPIs

The app has no usage analytics; checked at review, from the Worker's `learn data` log lines (S-24), a debug run on the owner's sessions and the owner's own use.

- **Groups that can be played** (owner's groups showing a grid, not "Not enough words…") — baseline: 0 (not available). Target: at least 8 of 10 within 14 days of ship.
- **Words left out for missing or unusable clues** (over all candidates) — baseline: unknown, measured in a debug run. Target: ≤ 10%; above that, a follow-up tunes the kind `clues` prompt and bumps its cache key (S-16).
- **Clue leaks** (shown clues where masking replaced at least one place, over all shown clues) — baseline: unknown, debug run. Target: ≤ 10% for clues 1 and 2; above that, tune the prompt.
- **Grading works** (targets found on clue 1, over all targets, in the owner's play) — baseline: none. Target: between 30% and 80% in the first 30 days; outside it, clue 1 is too easy or too hard and the prompt is tuned.

## 8. Open questions

- [ ] When the shared page gets live state, should people-written clues replace the AI clues or sit beside them? Carried from the small spec. Default now: beside; nothing is built (D-11). — owner: Maksym, due: when a shared-page live-state spec is started.
- [ ] Irregular forms ("ran" for "run", "went" for "go") are not masked by the shared matching rule. Add a Worker clue check that rejects a clue with any form of the word, with a cache key bump? Default now: no; the prompt says "never the word itself" and §7 measures leaks. — owner: Maksym, due: after the first debug run of §7.
- [ ] Real use needs the owner's learn-kit deploy steps (the `vocab-learn-data` KV namespace, the learn allowance migration, deploy); until then the exercise shows the load error line (AC-19). Default now: build and flip `available`; the web list needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.

## Implementation status

Implemented 2026-10-15 on `feat/learn-exercises`, test-first (commits `feat(learn-guess-my-word): ...`). All 25 ACs have code and tests; no AC needed an Implementation note. §8 questions keep their defaults (people-written clues beside AI clues, nothing built; irregular forms not masked; the owner's learn-kit deploy steps are still needed for real use).

**Done.** `lib/features/learn/guess_my_word/` (`GuessMyWord` notifier family + `GuessState`, `GuessRound`, `GuessWord`; `GuessMyWordScreen` with the grid and tile), `case 'guess-my-word'` in `exerciseScreen`, `available: true` in `exercises.json` and `exercises.dart`. No kit file and no Worker code changed (only the exercise list flipped). Tests: `learn_guess_my_word_notifier_test.dart` (17), `learn_guess_my_word_screen_test.dart` (13), AC-25 in `vocab-photo-api/test/learn.test.mjs`; the flip updated `learn_screen_test`, `exercise_route_test`, `learn_exercises_test`, `learn.test.mjs` and `learn-exercises.test.mjs`.

**Notes.**
- A target's right tap and the pause live in the notifier (`Timer` of 600 ms, cancelled on dispose); the screen only draws.
- Candidates, clue masking and the usable rule follow S-51; the stored definition is clue 3 via `definitionCard`, so no `definition` call is made.
- Found words show a points badge, the answer of a missed target is tinted red, a greyed word is dimmed and struck through (look chosen here, same card style as `MatchCard`).
- Long press on a tile uses a manual `Tooltip` (translation); clues have none.
- The Worker's web list shows the row as tickable and needs a deploy to match.
