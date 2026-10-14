---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead"]
updated_at: "2026-10-14"
feature_size: "S"
---

# Spec — learn-match-definitions

> **Glossary:** repo-root [CONTEXT](../../../CONTEXT.md) · [definition-mode CONTEXT](../definition-mode/CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-match-synonyms CONTEXT](../learn-match-synonyms/CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** [`learn-exercises/match-definitions.md`](../learn-exercises/match-definitions.md) (the clarified small spec — the starting point), [`learn-exercises/hard-decisions.md`](../learn-exercises/hard-decisions.md) (H-01, H-02, H-08, H-09 — the authority; H-09 replaces the small spec's dictionary branch), [`learn-exercises/decisions.md`](../learn-exercises/decisions.md) (D-01..D-10, S-01..S-39, esp. the board contract S-35..S-39; this spec adds S-40..S-42), [`learn-match-synonyms/spec.md`](../learn-match-synonyms/spec.md) incl. "Implementation status" (the built sibling — this spec mirrors it), the built kit in `lib/features/learn/kit/` (`MatchBoard`, `MatchItem`, `cardText`, `missesText`, `maskWord`, `ExerciseScaffold`, `ExercisePhase`, `failureOf`, `splitRounds`, `ResultSummary`, `exerciseWordsProvider`, `exerciseRandomProvider`), `lib/features/learn/match_synonyms/` (notifier, `usableSynonymPairs`, screen), `lib/core/services/learn_api_service.dart` (`LearnDataKind.definition`, `DefinitionData`), `lib/core/models/word_pair.dart` (`definition`), `lib/core/dialogues/dialogue_match.dart` (`matchPlaces`), the Worker's definition kind in `vocab-photo-api/src/learn/data.ts` and `prompts.ts`, and the stored sense format in `vocab-photo-api/src/define.ts` (`formatSense`: "definition: …\nexample: …") and `lib/core/services/quizlet_cards.dart` (back + "\n" + example).

## 1. Context

The learner has a word group selected on the learn page and wants a no-typing drill that ties each English word to its English meaning, without the native language. Match word and definition is that drill: the same two-column match board as Match synonyms (D-01), the group's words on the left in group order, their definitions shuffled on the right; tap a word and then its definition; a right pair locks, a wrong pair shakes and counts a miss for the word. Only the pair data and the copy differ from Match synonyms.

Why now: `hard-decisions.md` Wave 1 lists it second, after match-synonyms, which is built and whose board was fixed as a kit widget for exactly this reuse (S-35..S-39). The Worker's exercise data route already has the sense-aware definition kind (S-15, H-09); it has no app user yet.

Committed approach: one `@riverpod` notifier plus one round body on top of the kit, the board used unchanged. On open the notifier reads the group's words (`exerciseWordsProvider`, S-08); each word's definition line comes from its stored definition (the sense the learner chose) and, only for words without one, from one Worker call for the group (`LearnApiService.fetchData(LearnDataKind.definition, …)`, sense of the translation, H-09; never written to the word). Each definition is masked (its own word shows as "___", D-08), cut to fit a card (D-10), filtered for fairness (S-38), split into rounds of 3–6 (D-02), and the right column is shuffled once (S-27, S-34, S-36). The frame is `ExerciseScaffold`; nothing is saved (D-04).

Traceability and decisions taken without the owner (owner not available, depth easy; each is an agent decision the owner may revise):
- **H-09 over D-09 and the small spec.** The small spec's dictionary fallback ("first sense", "not found" / "unavailable") is replaced by the Worker's definition kind, which answers in the sense of the translation; "none" leaves the word out. The "never written to the word" and "a translation is never a stand-in" parts stay.
- **The definition line (S-40).** A stored definition can be a picked dictionary sense ("definition: …" plus an "example: …" line), a Quizlet back plus its example on a second line, or text the learner typed. A card shows one line: the text after "definition:", else the first line that is not an example line. A stored definition without such a line counts as empty and is asked of the Worker.
- **Masking, word forms (closes the small spec's open question).** Masking uses the one kit rule (`maskWord`, S-12, the app-wide match rule): the word as a whole word in any case, plus the endings -s, -es, -ed, -ing, and a phrase's words in order. Irregular forms ("went" for "go") are not hidden; the Worker's prompt already asks for a definition that does not use the word. A definition that says nothing once masked (only "___", punctuation or spaces) leaves the word out.
- **Card text order (S-40).** definition line → mask → `cardText` (D-10, about 120 characters); the clash rule (S-38) compares that shown text, so two definitions that differ only after the cut cannot show as two equal cards.
- **No hint and no reading aloud.** The small spec's "long press reads the card aloud" is not built: the board's long press shows a card's hint (S-36), and adding speech would change the kit board, which this exercise must reuse unchanged. Both columns have no hint (the translation is not shown, English-only goal), so a long press does nothing. Listed in §8.
- **Shared code moves to the kit (S-41).** The fairness loop, the round type, the out-of-order shuffle, the round state and the summary delay of match-synonyms are now used by two exercises, so they are cut-and-pasted into one kit file with neutral names; match-synonyms keeps its behaviour and its tests (only names change).
- **Errors.** One Worker call or none: if every word has a stored definition line no call is made and the exercise works offline. If a call is needed and fails, the whole exercise shows the error frame (D-05, no partial round), even though some words had stored definitions.
- **Copy chosen here:** title "Match word and definition" (the exercise's name), line "Tap a word, then its definition", counter "Round 1 of 2" (2+ rounds only), not-enough line "Not enough words with definitions for this group" (from the small spec), results "no misses" / "1 miss" / "3 misses" (S-37).
- **Files:** `lib/features/learn/match_definitions/` (S-30), `lib/features/learn/kit/definition_text.dart` (S-40), `lib/features/learn/kit/match_rounds.dart` (S-41); `case 'match-definitions'` in `exerciseScreen`; `available: true` in `exercises.json` (app and Worker) and `exercises.dart` (S-02). No Worker code change.

## 2. Goals

- The learner can drill every word of the selected group that has a fair English definition, by tapping only, with no translation on screen.
- A word's definition is the sense the learner means: their stored definition first, else one in the sense of the word's translation.
- Every board is fair: no card gives its word away, no two cards read the same, and every word has exactly one right card.
- The match board is reused with zero changes; a group whose words all have stored definitions costs nothing on the Worker.

## 3. Non-goals

- No saved results and no change to any word: round definitions are never written to the word (D-04, D-09, H-09).
- No translation as a fallback and no translation hint: it would break the English-only goal (D-09).
- No dictionary senses lookup in the exercise: the sense-aware Worker kind replaces it (H-09).
- No play on the shared page or the web learn page (D-11, H-07).
- No reading cards aloud in v1 (see §1 and §8), and no hiding of irregular word forms.

## 4. User stories

### US-01: Start the exercise for a group
**As a** learner
**I want** to tick Match word and definition on the learn page and press Start with a word group selected
**So that** I drill exactly that group's words in English

### US-02: Link words to definitions
**As a** learner
**I want** to tap a word and then the definition I think matches it, in either order
**So that** I see at once whether I recognise the word's meaning

### US-03: My sense of the word
**As a** learner
**I want** the definition I chose for a word to be the one on the card, and a missing one to follow my translation's sense
**So that** a word with several meanings is asked in the meaning I am learning

### US-04: Fair cards
**As a** learner
**I want** definitions that never show their own word, fit on a card and never read the same as another card
**So that** a miss always means I did not know the word

### US-05: See my round results
**As a** learner
**I want** a summary after each round listing each word with its misses
**So that** I know which words to look at again

### US-06: Clear stop when the group cannot be practised
**As a** learner
**I want** a plain message when the group has too few words with definitions or the definitions cannot be loaded
**So that** I am never left on an empty or broken round

### US-07: Practise any session without changing it
**As a** learner
**I want** to practise a group of the current session or of a History session
**So that** old sessions are useful too, and practising never changes my words

## 5. Acceptance criteria

### Opening and the board

### AC-01 (US-01) — happy path
**Given** the app after this feature and a selected word group of 6 words to learn that all have a stored definition
**When** the learner opens the learn page, ticks "Match word and definition" in Step 1 and presses Start
**Then** the row can be ticked (it no longer shows "Coming soon"), the exercise opens with the title "Match word and definition", and one board shows the line "Tap a word, then its definition", the 6 words in group order on the left and their 6 definitions on the right, with no round counter; the Worker is not asked, and no stored definition changes.

### AC-02 (US-04) — domain invariant
**Given** any round of the exercise
**When** its board shows
**Then** the left column holds the round's words in group order, the right column holds exactly their definitions (one each, none extra, none missing), the right column is not in the same order as the left, and the same seed always gives the same right order.

### AC-03 (US-02) — happy path
**Given** a board with no pair linked
**When** the learner taps a word and then its definition, or the definition first and then the word
**Then** both cards lock as linked with the same pair number ("1" for the first pair), look done and ignore later taps; the word's miss count does not change.

### AC-04 (US-02) — error
**Given** a board on which the learner has selected the word "harbour"
**When** the learner taps a definition that belongs to another word
**Then** nothing is linked, both cards shake once and are unselected, and "harbour" gets one miss; every further wrong try adds one more miss.

### AC-05 (US-02) — happy path
**Given** a round with one pair left to link
**When** the learner links it
**Then** the last pair locks visibly, and about half a second later the round summary opens by itself.

### AC-06 (US-02) — happy path
**Given** a board with a card not yet linked
**When** the learner long-presses a word or a definition
**Then** nothing happens: no popup, no translation, no sound, no selection change and no miss.

### Where a definition comes from

### AC-07 (US-03) — happy path
**Given** a word "bank" (translation "берег") whose stored definition is "definition: the land along the side of a river\nexample: We sat on the bank."
**When** its card shows
**Then** it reads "the land along the side of a river" (no "definition:" label, no example), and the Worker is not asked about "bank".

### AC-08 (US-03) — cross-context
**Given** a group of 5 words of which "bank" (translation "берег") has an empty stored definition and the others have stored ones
**When** the exercise opens
**Then** the Worker is asked once, for "bank" only, with its translation; the card shows the Worker's definition in the river sense; after the exercise the row's stored definition is still empty.

### AC-09 (US-03) — cross-context
**Given** the learner changed a word's definition on the Words screen after a previous open
**When** the learner opens the exercise again
**Then** the card shows the new stored definition.

### AC-10 (US-03) — domain invariant
**Given** a word "tripod" with no stored definition, for which the Worker answers "none", and 4 other words with definitions
**When** the exercise opens
**Then** "tripod" is left out (not on the board, not in the summary), the other 4 words show in one round, and no translation appears in its place.

### AC-11 (US-03) — domain invariant
**Given** a word whose stored definition is a Quizlet back plus an example on the next line ("a place where ships stay\nThe harbour was full.")
**When** its card shows
**Then** it reads "a place where ships stay" only.

### Fair cards

### AC-12 (US-04) — domain invariant
**Given** the word "walk" with the definition "Walk: to go on foot; she walks and walked home, not by sidewalk" and the phrase "give up" with "to give up means to stop trying"
**When** their cards show
**Then** they read "___: to go on foot; she ___ and ___ home, not by sidewalk" and "to ___ means to stop trying": every whole-word place of the word, in any letter case and with the endings -s, -es, -ed or -ing, shows as "___"; a word inside another word ("sidewalk") or an irregular form (such as "went" for "go") is not hidden.

### AC-13 (US-04) — domain invariant
**Given** a word whose definition is only the word itself ("Echo.")
**When** the board is built
**Then** the word is left out, because its masked card would say nothing.

### AC-14 (US-04) — domain invariant
**Given** a definition of 300 characters whose first sentence ends at character 80, and another of 300 characters with no sentence end in the first 120 characters
**When** their cards show
**Then** the first reads its first sentence only, and the second its text up to the last whole word within about 120 characters followed by "…"; card text wraps onto more lines and is never cut further, and the board scrolls if the round does not fit the screen.

### AC-15 (US-04) — domain invariant
**Given** a group, in this order, of "big" and "large" whose definitions read the same ignoring case and extra spaces once masked and cut, and "bank" twice (one "банк", one "берег")
**When** the board is built
**Then** only the first of each clash in group order stays ("big", the first "bank"), so no two cards on a board read the same and every word has exactly one right card.

### Rounds, empty and error states

### AC-16 (US-05) — domain invariant
**Given** a group of 8 usable words
**When** the exercise opens
**Then** it runs two rounds of 4 words in group order; 7 give 4 + 3, 13 give 5 + 4 + 4, 6 give one round (rounds of 3 to 6, never under 3); with 2+ rounds the board shows "Round 1 of 2" above the line.

### AC-17 (US-06) — error
**Given** a selected group with 3 or more words to learn of which fewer than 3 are usable after the definitions are gathered
**When** the learner starts the exercise
**Then** only "Not enough words with definitions for this group" and "Back" show, no round starts, and Back returns to the learn page.

### AC-18 (US-06) — error
**Given** a selected group with fewer than 3 words to learn (including one whose words were all deleted)
**When** the learner starts the exercise
**Then** only "Not enough words for this exercise" and "Back" show, and the Worker is not asked.

### AC-19 (US-06) — error
**Given** the phone is offline (or the Worker fails, times out or has no exercise storage) and at least one word of the group has no stored definition
**When** the exercise opens
**Then** only "Could not load the exercise. Check the connection and try again." and "Retry" show and no round starts, even if other words have stored definitions; back online, Retry loads the definitions and round 1 starts.

### AC-20 (US-06) — cross-context
**Given** the Worker's daily exercise allowance is used up and a needed definition is not on its cache
**When** the exercise opens
**Then** only "Today's exercise limit is reached. Try again tomorrow." and "Back" show; when the Worker answers that requests are too frequent, "Too many requests. Wait a moment and try again." and "Retry" show instead.

### Summary, sessions and people

### AC-21 (US-05) — happy path
**Given** a round of 4 words in which "harbour" got 2 misses, "bank" 1 and the others none
**When** the summary opens
**Then** it lists every word of the round in group order with "2 misses", "1 miss" or "no misses"; "Next round" while rounds remain, "Done" after the last; Next round opens a fresh board, Done returns to the learn page (or opens the next ticked exercise, as today).

### AC-22 (US-07) — domain invariant
**Given** a round in progress or finished
**When** the learner leaves with Back or Done
**Then** nothing is kept: no word result, no change to any word, translation, definition, group or dialogue; opening again starts at round 1 with nothing linked.

### AC-23 (US-07) — cross-context
**Given** the learn page opened for a History session with a selected group
**When** the learner plays the exercise to the end
**Then** only that session's group words are used and only those without a stored definition line are sent to the Worker (with their translations), and the History session is unchanged afterwards (same words, groups and last-changed time).

### AC-24 (US-01) — authorization
**Given** a partner opens the web learn page of a published session
**When** they look at Step 1
**Then** Match word and definition is listed with the same name and step as in the app and cannot be played there; only the learner, in the app, can play it (the Worker's exercise data is behind the app's secret).

### AC-25 (US-02) — cross-context
**Given** the match board as built for Match synonyms
**When** this exercise ships
**Then** the board works as in AC-02..AC-06 and AC-14 with no change to the board, and Match synonyms behaves exactly as before (its existing checks still pass).

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Worker calls per open (and per Retry) | 0 when every word has a stored definition line or the group has under 3 words to learn; else exactly 1, holding only the words without one; 0 during rounds, Next round and summary | widget test with a counting `learnApiService` fake |
| Day-cap cost of a repeat open | 0 units (all cache hits) | existing Worker test (all-hit request takes none, S-18) |
| Start to first board, release build, mid-range Android phone | ≤ 1.0 s with all stored definitions; ≤ 1.5 s for a cached group on a good network | manual check before ship |
| Start to error line when the Worker does not answer | ≤ 31 s (app timeout 30 s, S-13) | unit test with a short `dataTimeout` |
| Determinism | same words + same answers + same seed → same usable words, rounds and right orders, 100% | unit tests with an overridden `exerciseRandomProvider` (S-27) |
| Fairness | 0 boards with an unmasked own word, two equal cards or a second right card over 1000 seeds on a fixture with clashing, duplicate, self-containing and long definitions | unit test of the usable-words filter |
| Board reuse | 0 changed lines in `match_board.dart`; match-synonyms tests pass with only renamed imports | `git diff` at `sdd:review`; `tool/test.sh changed` |
| Test coverage | every AC has a unit or widget test; AC-24 by the Worker learn-page test | `tool/test.sh changed` |

### 6.1 Security / privacy

- **Data classification:** internal — the learner's own words, translations and definitions.
- **Personal data touched:** none new. Only the words without a stored definition line go to the Worker (word, translation, row id), as the synonym kind already does; stored definitions never leave the phone for this exercise.
- **AuthZ/AuthN impact:** none new. The exercise data route is behind the app's secret (S-14); no play surface on the web.
- **Abuse cases:**
  - Partner tries to play from a web link: the web learn page lists the exercise only (AC-24).
  - Repeated opens draining the AI budget: stored definitions take no call; cache hits take nothing; misses take one unit per call against the daily cap (AC-20, S-18).
  - AI or stored text with markup or great length: shown as plain text, masked and cut (AC-12, AC-14); the Worker caps a definition at 160 characters.
  - A definition giving the word away or making two right answers: masked, or left out by the clash rule (AC-12, AC-13, AC-15).
- **Security review:** N/A — no new data flow, route, secret or storage.

## 7. Metrics / KPIs

The app has no usage analytics; checked at review, from the Worker's `learn data` log lines (S-24) and the owner's own use.

- **Board reuse** — baseline: board built for match-synonyms. Target: 0 changes to the board file at this feature's `sdd:review`.
- **Groups that can be practised** (owner's groups showing a board, not "Not enough words…") — baseline: 0 (not available). Target: at least 8 of 10 within 14 days of ship.
- **Words served without an AI call** (stored definitions + cache hits, over all words shown) — baseline: 0. Target: ≥ 70% in the first 30 days after deploy.
- **Unfair boards reported by the owner** (word visible in its definition, equal cards, wrong sense) — baseline: n/a. Target: 0 in the first 30 days.

## 8. Open questions

- [ ] Should a long press read a card aloud, as the small spec asked? It needs a board change (a long-press callback) shared with match-synonyms. Default now: no sound, long press does nothing (AC-06). — owner: Maksym, due: any time; a later change to S-36.
- [ ] Real use needs the owner's learn-kit deploy steps (the `vocab-learn-data` KV namespace, `0006_learn_allowance.sql`, deploy) for words without a stored definition; until then those groups show the error line (AC-19), groups with all stored definitions already work. Default now: build and flip `available`; the web list needs a deploy to show the row as tickable. — owner: Maksym, due: before the owner's first real use.
- [ ] pick-the-answer's kind B shows the stored definition as is (a picked sense still carries "definition:" and its example). Default now: unchanged here (no visible change outside this exercise); S-40 says later users of a stored definition take the definition line. — owner: Maksym (a visible change to a built exercise), due: before pick-the-answer is next touched.

## Implementation status

Implemented 2026-10-15 on `feat/learn-exercises`, test-first. All 25 ACs have code and tests; no AC needed an Implementation note. §8 questions keep their defaults (long press does nothing; the owner's learn-kit deploy steps are still needed for words without a stored definition).

**Done.** S-41 refactor: `lib/features/learn/kit/match_rounds.dart` (`MatchPair`, `usableMatchPairs`, `MatchRound`, `shuffledOutOfOrder`, `MatchRoundsState`, `matchSummaryDelay`), cut from match-synonyms; its tests changed only names (a local `usableSynonymPairs` wrapper in the test). S-40: `kit/definition_text.dart` (`definitionText`, `definitionCard` = line, mask, cut; null when empty or only "___"). Exercise: `lib/features/learn/match_definitions/` (`MatchDefinitions` notifier, `MatchDefinitionsScreen`), `case 'match-definitions'`, `available: true` in `exercises.json` and `exercises.dart`. `match_board.dart` is unchanged. Tests: `learn_definition_text_test` (9), `learn_match_definitions_notifier_test` (18, incl. 1000-seed fairness), `learn_match_definitions_screen_test` (11); AC-24 by a new case in `vocab-photo-api/test/learn.test.mjs`. Updated for the flip: `learn_screen_test`, `learn_exercises_test`, `exercise_route_test`, `learn.test.mjs`, `learn-exercises.test.mjs`.

**Notes.**
- A stored line that is only the word ("Echo.") leaves the word out; the Worker is asked only for words whose stored definition line is empty.
- The right card text is the shown form (`definitionCard`) and is not passed through `cardText` again: a cut text can be one character over 120 and would be cut twice.
- The Worker's web list shows the row as tickable and needs a deploy to match.
