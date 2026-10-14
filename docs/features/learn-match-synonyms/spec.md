---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-14"
feature_size: "S"
---

# Spec — learn-match-synonyms

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/match-synonyms.md`](../learn-exercises/match-synonyms.md) (the clarified small spec — the starting point), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01, H-02, H-07, H-08 — the authority), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-01..D-07, D-10, D-11, S-01..S-34; this spec adds S-35..S-39), "Implementation status" of [`learn-kit/spec.md`](../learn-kit/spec.md), [`learn-pick-the-answer/spec.md`](../learn-pick-the-answer/spec.md) and [`learn-remember-or-not/spec.md`](../learn-remember-or-not/spec.md), the built kit in `lib/features/learn/kit/` (`ExerciseScaffold`, `ExercisePhase`, `failureOf`, `splitRounds`, `ResultSummary`, `WordOutcome`, `exerciseWordsProvider`, `exerciseRandomProvider`, `matchPlaces` via `word_marks.dart`), `lib/features/learn/exercise_screens.dart`, `lib/features/learn/exercises.dart`, `lib/core/services/learn_api_service.dart` (`LearnApiService.fetchData`, `LearnDataKind.synonym`, `SynonymData`, `LearnApiException`), `lib/core/story/word_grouping.dart` (`wordsToLearn`, `groupWords`, `maxGroupSize` 19), the Worker's synonym kind in `vocab-photo-api/src/learn/data.ts` and `prompts.ts`.

## 1. Context

The learner has a word group selected on the learn page and wants a quick, no-typing drill that ties each English word to a neighbour with the same meaning. Match synonyms is that drill: two columns per round, the group's words on the left, their synonyms shuffled on the right, tap a word and then its synonym; a right pair locks, a wrong pair shakes and counts a miss for the word. It is the first exercise that loads AI data from the Worker, and the first user of the **match board**, the two-column round that match-definitions reuses next with definitions instead of synonyms (D-01; match-antonyms is cancelled, H-08).

Why now: `hard-decisions.md` Wave 1 starts with this exercise. The kit, the Worker's exercise data route with its synonym kind, its cache and its day cap are built (learn-kit), and two offline exercises (pick-the-answer, remember-or-not) have proved the frame. The data route has no app user yet; this exercise is it, and the board must be fixed now so match-definitions only supplies different pair data.

Committed approach: one `@riverpod` notifier plus one round body on top of the kit, plus one new kit widget, `MatchBoard`, with a contract that knows nothing about synonyms (S-35, S-36). On open the notifier reads the group's words (`exerciseWordsProvider`, S-08), asks the Worker once for all of them (`LearnApiService.fetchData(LearnDataKind.synonym, …)`, one call per group, cached per word on the Worker, D-03, S-14..S-17), keeps the words whose synonym is fair (S-38), splits them into rounds of 3–6 (`splitRounds`, D-02), shuffles each round's right column once (`exerciseRandomProvider`, S-27, S-34), and counts misses per word for the summary. The frame (loading, error with Retry, not enough words, summary with Next round / Done) is `ExerciseScaffold`. Nothing is saved (D-04; only Step 3 writes word results, S-23).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- The small spec's open question ("may a synonym be another word of the group?") is closed: no. The Worker caches each word separately, so it cannot see the other words of a round; the app enforces it with the clash rule in group order (S-38, extends D-07).
- The Worker already accepts "one English word or short phrase", up to 40 characters (S-15, `prompts.ts`). The small spec's "one English word" is relaxed to that: phrasal synonyms ("put off" for "postpone") are fair, and changing the prompt would mean a cache version bump for no learner gain (S-39). A synonym that holds the word itself as a whole word is left out (S-38).
- A group with fewer than 3 words to learn shows the default "Not enough words for this exercise" without asking the Worker (saves the day cap); the synonym-specific line shows only when the Worker's answers leave fewer than 3 usable words (S-39).
- Errors follow the kit's frame (S-06), so a day limit shows its own line with Back, not Retry; the small spec's "one error line and Retry" holds for every other failure.
- The long-press hint is the tapped word's translation in a small popup; a word without a translation has no hint. The hint never selects and never counts.
- The right column is shuffled so that it never matches the left order exactly (a 3-pair round would otherwise be in order one time in six) (S-36).
- The summary opens by itself shortly after the last pair locks, so the learner sees the last lock first; no extra button.
- Copy chosen here: the line "Tap a word, then its synonym", the counter "Round 1 of 2" (shown only when there are 2+ rounds), the not-enough line "Not enough words with synonyms for this group" (from the small spec), and the results "no misses" / "1 miss" / "3 misses".
- Files: `lib/features/learn/kit/match_board.dart` (kit, S-35..S-37), `lib/features/learn/match_synonyms/` (S-30); the `exerciseScreen` switch gets `case 'match-synonyms'`; `available: true` is flipped in `exercises.json` (app and Worker) and `exercises.dart` (S-02).

## 2. Goals

- The learner can drill every word of the selected group that has a fair synonym, by tapping only, in rounds that fit one phone screen.
- Every round is fair: each word has exactly one right card, no two cards read the same, and a miss always means the learner linked the wrong pair.
- The match board is a kit widget with a contract that match-definitions uses unchanged, giving only its own pair data and copy.
- Opening the same group again costs nothing on the Worker's day cap (cached answers).

## 3. Non-goals

- No saved results: a Stage 1 exercise shows its misses in the round summary only (D-04, S-23).
- No synonym translation and no hint on the right column: the hint covers the word only, so the synonym stays the thing to recognise.
- No play on the shared page or the web learn page (D-11, H-07): a table-mate race needs live state and its own spec.
- No change to the Worker: the synonym kind, its prompt, cache and caps stay as built (learn-kit); only the Worker's exercise list flips `available`.
- No antonyms mode (H-08): the board can host it later, but nothing here builds it.

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Match synonyms on the learn page and press Start with a word group selected
**So that** I drill exactly that group's words

### US-02: Link words to synonyms
**As a** learner
**I want** to tap a word and then the synonym I think matches it, in either order
**So that** I see at once whether I recognise the word's meaning

### US-03: Fair board
**As a** learner
**I want** each word to have exactly one right synonym and no two cards to read the same
**So that** a miss always means I did not know the word

### US-04: Hint by long press
**As a** learner
**I want** to long-press a word to see its translation
**So that** I can recall a word I have forgotten without leaving the round

### US-05: See my round results
**As a** learner
**I want** a summary after each round listing each word with its misses
**So that** I know which words to look at again

### US-06: Clear stop when the group cannot be practised
**As a** learner
**I want** a plain message when the group has too few words with synonyms or the synonyms cannot be loaded
**So that** I am never left on an empty or broken round

### US-07: Practise any session without changing it
**As a** learner
**I want** to practise a group of the current session or of a History session
**So that** old sessions are useful too, and practising never changes my words

### US-08: Reuse the board for the next match exercise
**As a** learner
**I want** the next match exercise (word and definition) to behave exactly like this one
**So that** I learn the board once

## 5. Acceptance criteria

### Opening and the board

### AC-01 (US-01) — happy path
**Given** the app after this feature, the phone online, and a selected word group of 6 words to learn for which the Worker gives a fair synonym each
**When** the learner opens the learn page, ticks "Match synonyms" in Step 1 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens with the title "Match synonyms", a loading indicator shows while the synonyms load, and then one board shows the line "Tap a word, then its synonym", the 6 words in group order on the left and their 6 synonyms on the right, with no round counter (there is one round).

### AC-02 (US-03) — domain invariant
**Given** any round of the exercise
**When** its board shows
**Then** the left column holds the round's words in group order, the right column holds exactly their synonyms (one each, none extra, none missing), the right column is not in the same order as the left, and the same seed always gives the same right order.

### AC-03 (US-01) — cross-context
**Given** a group opened once already (its synonyms are on the Worker's cache)
**When** the learner opens the exercise for the same group again
**Then** the same synonyms show, the exercise asks the Worker exactly once for the whole group, and the Worker's daily exercise allowance is not used up by the repeat open.

### Pairing

### AC-04 (US-02) — happy path
**Given** a board with no pair linked
**When** the learner taps a word and then its synonym
**Then** both cards lock as linked: they show the same pair number ("1" for the first pair linked), look done, and ignore every later tap for the rest of the round; the word's miss count does not change.

### AC-05 (US-02) — happy path
**Given** a board with no card selected
**When** the learner taps a synonym first and then its word
**Then** the pair locks exactly as in AC-04 (either order works).

### AC-06 (US-02) — error
**Given** a board on which the learner has selected the word "big"
**When** the learner taps a synonym that belongs to another word
**Then** nothing is linked, both tapped cards shake once and are unselected, and "big" gets one miss; trying another wrong synonym for "big" adds another miss (each wrong try counts).

### AC-07 (US-02) — happy path
**Given** a board with one card selected
**When** the learner taps the same card again, or taps another card in the same column
**Then** the first case unselects it, the second moves the selection to the new card; neither counts a miss.

### AC-08 (US-05) — happy path
**Given** a round with one pair left to link
**When** the learner links it
**Then** the last pair locks visibly, and about half a second later the round summary opens by itself.

### Fair synonyms

### AC-09 (US-03) — domain invariant
**Given** a group in which the Worker gives no synonym for "tripod" (it answers "none") and gives fair synonyms for the other 5 words
**When** the exercise opens
**Then** "tripod" is left out: it is not on the board and not in the summary; the other 5 words show in one round.

### AC-10 (US-03) — domain invariant
**Given** a group, in this order, of "big" (synonym "large"), "huge" (synonym "large "), "car" (synonym "automobile"), "automobile" (synonym "car"), "dog" (synonym "hound")
**When** the board is built
**Then** "big", "car" and "dog" are kept and "huge" and "automobile" are left out: no two right cards read the same ignoring case and extra spaces, and no left word is also a right card, so every word has exactly one right card; the earlier word in group order is the one that stays.

### AC-11 (US-03) — domain invariant
**Given** a group in which the same English word appears twice (two rows "bank", one with the translation "банк", one with "берег")
**When** the board is built
**Then** only the first "bank" in group order is on the board, so no two left cards read the same.

### AC-12 (US-03) — domain invariant
**Given** a word "house" whose synonym from the Worker is "small house"
**When** the board is built
**Then** "house" is left out, because its synonym holds the word itself.

### AC-13 (US-03) — domain invariant
**Given** a word or a synonym longer than fits on one line of its column
**When** the board shows
**Then** the full text wraps onto more lines and stays readable (text over about 120 characters is cut at its first sentence, else at a whole word plus "…"), and the board scrolls if the round does not fit the screen.

### Hint

### AC-14 (US-04) — happy path
**Given** a board with the word "big" (translation "великий") not yet linked
**When** the learner long-presses "big"
**Then** a small popup shows "великий"; nothing is selected or unselected, no miss is counted, and long-pressing a synonym shows nothing (a synonym has no hint); a word without a translation shows no popup.

### Rounds, empty and error states

### AC-15 (US-05) — domain invariant
**Given** a group of 8 usable words
**When** the exercise opens
**Then** it runs two rounds of 4 words each in group order; 7 usable words give 4 + 3, 13 give 5 + 4 + 4, and 6 give one round of 6 (rounds of 3 to 6, never under 3); with 2+ rounds the board shows "Round 1 of 2" above the line.

### AC-16 (US-06) — error
**Given** a selected group with 3 or more words to learn of which fewer than 3 are usable after the Worker answers
**When** the learner starts the exercise
**Then** only the message "Not enough words with synonyms for this group" and a "Back" button show, no round starts, and Back returns to the learn page.

### AC-17 (US-06) — error
**Given** a selected group with fewer than 3 words to learn (including a group whose words were all deleted)
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked at all.

### AC-18 (US-06) — error
**Given** the phone is offline, or the Worker fails, times out or has no exercise storage
**When** the exercise opens
**Then** only the line "Could not load the exercise. Check the connection and try again." and a "Retry" button show and no round starts; when the phone is back online, Retry loads the synonyms and round 1 starts.

### AC-19 (US-06) — cross-context
**Given** the Worker's daily exercise allowance is used up and the group's synonyms are not on its cache
**When** the exercise opens
**Then** only "Today's exercise limit is reached. Try again tomorrow." and a "Back" button show; when the Worker answers that requests are too frequent, "Too many requests. Wait a moment and try again." and "Retry" show instead.

### Summary

### AC-20 (US-05) — happy path
**Given** a round of 4 words in which "big" got 2 misses, "car" 1 and the others none
**When** the summary opens
**Then** it lists every word of the round in group order with "2 misses", "1 miss" or "no misses"; it offers "Next round" while rounds remain and "Done" after the last; Next round opens the next board with nothing linked, and Done returns to the learn page (or opens the next ticked exercise, as the learn page does today).

### AC-21 (US-07) — domain invariant
**Given** a round in progress or finished
**When** the learner leaves the exercise with Back or Done
**Then** nothing about the round is kept: no word result is written, no word, translation, definition, group or dialogue changes, and opening the exercise again starts at round 1 with nothing linked and no misses.

### Sessions, people and reuse

### AC-22 (US-07) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner plays the exercise to the end
**Then** the board uses that session's group and words only, only those words (with their translations, for the sense) are sent to the Worker, and the History session is unchanged afterwards (same words, same groups, same last-changed time).

### AC-23 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 1
**Then** Match synonyms is listed with the same name and step as in the app, and the page offers no way to play it; only the learner, in the app, can play it (the Worker's exercise data is behind the app's secret).

### AC-24 (US-08) — cross-context
**Given** the board as a kit widget
**When** a second exercise gives it its own words and answers (for example definitions) with its own right-pair rule
**Then** it behaves exactly as in AC-02 and AC-04..AC-08, AC-13 and AC-14 without any change to the board, and the board itself never decides which pair is right.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per Retry) | exactly 1 for the whole group; 0 during rounds, Next round and summary; 0 when the group has under 3 words to learn | widget test with a counting `learnApiService` fake |
| Day-cap cost of a repeat open | 0 units (all cache hits) | existing Worker test `learn-data.test.mjs` (all-hit request takes none, S-18) |
| Start to first board, cached group, release build, mid-range Android phone, good network | ≤ 1.5 s | manual check before ship |
| Start to error line when the Worker does not answer | ≤ 31 s (app timeout 30 s, S-13) | unit test with a short `dataTimeout` |
| Determinism | same words + same synonym answers + same seed → same usable words, rounds and right orders, 100% | unit tests with an overridden `exerciseRandomProvider` (S-27) |
| Fairness | 0 boards with two equal cards or a second right card over 1000 seeds on a fixture with clashing synonyms, duplicate words and synonym-equals-word cases | unit test of the usable-words filter |
| Board reuse | `MatchBoard` has no reference to synonyms, `LearnApiService` or any notifier | review at `sdd:review` |
| Test coverage | every AC has a unit or widget test; AC-23 by the Worker learn-page test | `tool/test.sh changed` |
| Visual frame | uses `ExerciseScaffold` and `ResultSummary` only; no own loading, error or summary code | review |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words and translations.
- **Personal data touched:** none new. The group's English words and translations (with their row ids) go to the Worker once per open, the same data the Worker's definition and story routes already receive; the Worker caches answers keyed by a hash of word and translation, not by learner.
- **AuthZ/AuthN impact:** none new. The exercise data route is behind the app's secret (S-14); the shared page and the web learn page get no play surface.
- **Abuse cases:**
  - Partner tries to play from a web link: the web learn page lists the exercise only (AC-23).
  - Repeated opens draining the AI budget: cache hits take nothing; misses take one unit per call against the 200-a-day cap, and the per-IP limiter stays (AC-19, S-18).
  - AI text with markup or a very long answer: the Worker caps a synonym at 40 characters; the app shows it as plain text, wrapped and cut per D-10 (AC-13).
  - A synonym giving the word away or making two right answers: left out by the clash rule (AC-10..AC-12).
- **Security review:** N/A — no new data flow, route, secret or storage; the route and its limits were reviewed with learn-kit.

## 7. Metrics / KPIs

The app has no usage analytics; these are checked at review, from the Worker's `learn data` log lines (S-24) and by the owner's own use.

- **Board reuse** — baseline: no match board. Target: match-definitions ships with zero changes to `match_board.dart`, checked at its `sdd:review`.
- **Groups that can be practised** (owner's sessions where the selected group shows a board, not "Not enough words…") — baseline: 0 (exercise not available). Target: at least 8 of 10 of the owner's groups within 14 days of ship.
- **Cache hit share of synonym requests** (Worker log hits / (hits + misses), kind synonym) — baseline: 0. Target: ≥ 70% of words served from cache in the first 30 days after deploy.
- **Unfair boards reported by the owner** (two right cards, equal cards, a synonym that gives the word away) — baseline: n/a. Target: 0 in the first 30 days after ship.

## 8. Open questions

- [ ] The exercise works only after the owner's learn-kit deploy steps (create the `vocab-learn-data` KV namespace, apply `0006_learn_allowance.sql`, deploy). Until then every open shows the error line (AC-18). Default now: build and flip `available` anyway; the web list also needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.
- [ ] Synonyms may be short phrases (S-39), not only one word as the small spec said. Default now: accept the Worker's word or short phrase up to 40 characters. — owner: Maksym, due: any time; a prompt change needs a cache version bump (S-16).
