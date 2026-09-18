# Task 02 — The word limit is a cap, not a quota

|  |  |
|---|---|
| **Roadmap step** | [#2](../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 2 (parallel with task-03 — Worker + `test/` vs app files, disjoint) |
| **Depends on** | — |
| **Blocked on** | **D2** — when more words are highlighted than the maximum, which ones are dropped |
| **Unlocks** | task-08 |
| **Files** | `vocab-photo-api/src/index.ts` · `vocab-photo-api/README.md` · `lib/services/vocab_photo_service.dart` · `lib/screens/word_input_screen.dart` (the `limit:` argument only) |
| **Status** | code complete (steps 1-5); AC-1, AC-7 verified by grep, typecheck green. AC-3/4/5/6/8 are device/`curl` tests and are open. AC-2's `flutter analyze` half cannot pass as written — see Result below |

## Blocked on D2

> When more words are highlighted than the maximum, which ones are dropped — reading order, or the
> owner chooses?

The two options behave differently enough that the prompt text and the app's result dialog both
change:

- **Reading order** — the Worker keeps the first N in reading order and drops the rest. The prompt
  loses its current "most useful/valuable ones for a learner" ranking instruction, which is a
  *judgement* the model makes and the owner cannot see or predict.
- **Owner chooses** — the Worker returns everything it found (no `limit` at all), and the app's
  result dialog becomes the place the extra ones get pruned. The dialog already supports crossing
  words out before they are added (`_showVocabResultDialog`, `remainingWords`), so this is closer
  to shipped than it looks.

Answer D2 in `docs/roadmap.md` before starting. Step 1 below stands either way and can be done
first if you want to start unblocked.

## Prompt

The maximum-words setting behaves as a quota rather than a cap: when fewer words are highlighted
than the limit, unhighlighted words come back to fill it. `docs/idea-brief.md` §6 calls this the
weakest spot in the whole product — "every value the idea promises collapses if the app returns
words that were never marked", because then the list has to be pruned by hand and typing five words
is faster.

**The roadmap is too optimistic about this one.** It says the padding guard "is already in the
Worker prompt" and frames step 2 as "a device-verified test plus the drop-rule decision, not a
repair". The first half is true — `buildSystemPrompt` does say *"never pad or invent extra entries
to reach the limit"* (`vocab-photo-api/src/index.ts:81`) and `handleAnalyze` truncates server-side
too (`:256`). But read the rest of that prompt: it asks for *"the useful English words or short
phrases visible in it (for example on packaging, signs, book pages, or screens)"*. **The word
"highlighted" does not appear anywhere in the Worker, the app, or the prompt** —
`grep -ri highlight vocab-photo-api/src/ lib/` returns nothing.

So the model is not padding to reach a limit. It is doing what it was asked: returning every useful
word on the page. A photo of a book page has forty of those, and twenty come back. The defect is a
**missing instruction**, not a broken guard, and this task is a repair after all.

Do the following:

1. **Teach the prompt what a highlighted word is.** In `buildSystemPrompt`
   (`vocab-photo-api/src/index.ts:50`), make marked-word selection the primary rule rather than
   "useful words". State it positively and negatively: return only words the photo shows as
   visually marked — highlighter, underline, circle, box, pen stroke — and return an **empty array**
   when the photo has no marked words at all, even if it is full of useful vocabulary. The existing
   noise-filter line (numbers, single letters, barcodes, UI chrome) stays. The prompt already ends
   with "If no useful vocabulary is visible, respond with an empty array: []" — make it clear that
   an unmarked page is that case.
2. **Reconcile `limit` with D2.** Implement whichever D2 answer was chosen. If reading order: drop
   the "keep only the N most useful/valuable ones for a learner" clause from `limitLine` and say
   reading order instead. If owner-chooses: stop sending `limit` from the app and let the result
   dialog do the pruning. Keep the server-side `words.slice(0, options.limit)` truncation at `:256`
   in both cases — it is a cheap backstop against a runaway response, not the mechanism.
3. **Fix the query-param bug you will trip over while testing.** `lib/services/vocab_photo_service.dart:48-49`
   sends the string `'false'` for `with_desc` and `shortify_definishion` whenever those flags are
   *true*:

   ```dart
   if (withDesc) 'with_desc': 'false',
   if (shortifyDefinition) 'shortify_definishion': 'false',
   ```

   The Worker compares against `=== "true"` (`parseOptions`, `:44-45`), so both land as false. The
   photo call site passes `withDesc: true, shortifyDefinition: true`
   (`lib/screens/word_input_screen.dart:700-701`) and has been silently getting neither. Send
   `'true'`. Then re-check step 1 on a real photo, because descriptions coming back for the first
   time changes what the response looks like.
4. **Make the limit configurable, or justify 20.** It is hardcoded at
   `lib/screens/word_input_screen.dart:702`. The brief says a session is 5–10 words. Either surface
   it as a setting or drop the constant to something defensible and leave a comment saying why.
5. **Write down the new contract.** Update `vocab-photo-api/README.md`'s `## Endpoint` section:
   `/analyze` returns marked words only, the empty-array case is a valid successful response, and
   `limit` behaves per D2.

## Acceptance criteria

The honest ones here are device tests. The Worker has **no test runner installed** (`package.json`
has `typecheck` and nothing else), and the behaviour under test is a model's, so a unit test would
only prove the prompt string contains a word.

- [x] **AC-1** `grep -in highlight vocab-photo-api/src/index.ts` matches the prompt builder.
      (`src/index.ts:95`, inside `buildSystemPrompt`.)
- [~] **AC-2** `npm run typecheck` exits 0 ✅. `flutter analyze` exits **1**, on 5 pre-existing
      info-level lints in files this task does not touch — see Result below.
- [ ] **AC-3 — the defect itself.** Photograph a dense page of English text with **exactly 3 words
      highlighted**. The response contains exactly those 3 words. Not 4, not 20. Repeat on 3
      different pages; all 3 pass.
- [ ] **AC-4 — the empty case.** Photograph a page of English text with **nothing** highlighted.
      The response is `{"words":[],...}` and the app shows its empty-result state rather than a
      list of arbitrary words.
- [ ] **AC-5 — over the limit.** Photograph a page with more highlighted words than the limit. The
      behaviour matches the D2 answer: either the first N in reading order (check they really are
      the first N, top-to-bottom), or everything returned and prunable in the result dialog.
- [ ] **AC-6** The `curl` in `vocab-photo-api/README.md` against a photo with 2 highlighted words
      returns both, each with a non-empty `translation` **and** a non-empty `description` —
      proving step 3's fix landed.
- [x] **AC-7** `grep -n "'false'" lib/core/services/vocab_photo_service.dart` (moved by task-00)
      returns no matches.
- [ ] **AC-8** A photo with highlighted **Ukrainian** text, or highlighted numbers only, returns an
      empty array rather than guesses.

## Result

D2 was already answered in `docs/roadmap.md` — **reading order** — so step 2 took that branch:
the app keeps sending `limit`, and the prompt drops the ranking clause.

1. **Prompt teaches marked words** (`vocab-photo-api/src/index.ts`, `buildSystemPrompt`). Marked-word
   selection is now the primary rule, stated both ways: return only words the photo shows as
   visually marked (highlighter, underline, circle, box, pen/pencil stroke, arrow), and a word
   counts as marked only if the mark is visible. The negative half is explicit — "A dense page of
   valuable vocabulary with nothing marked on it yields an empty array — that is the correct
   answer, not a failure" — and the closing line became "If the photo has no marked English
   vocabulary — including a photo full of unmarked useful words — respond with an empty array: []".
   The noise filter stayed and grew one clause for AC-8: marked text that is not English (Ukrainian,
   for example) is skipped rather than guessed at. The user message is now "Extract the **marked**
   vocabulary words from this photo."
2. **`limit` reconciled with D2.** `limitLine` lost "keep only the N most useful/valuable ones for a
   learner" and now says: over the limit, keep the first N **in reading order (top to bottom, then
   left to right)** and drop the rest, "do not rank them by how useful or valuable they look". The
   no-limit branch also asks for reading order, so the server-side `words.slice(0, limit)` at
   `handleAnalyze` truncates the right end of the list; it is commented as a backstop, not the
   mechanism.
3. **Query-param bug fixed.** `lib/core/services/vocab_photo_service.dart:48-49` now sends `'true'`
   for `with_desc` and `shortify_definishion`. The photo call site has been asking for descriptions
   and getting none since it was written; descriptions now come back for the first time, which is
   why AC-6 exists and why AC-3 wants a re-check on a real photo.
4. **The limit is justified, not surfaced.** Kept at 20 but lifted out of the call site into
   `_photoWordCap` in `lib/features/word_input/word_input_screen.dart` with the reasoning next to
   it: the brief puts a session at 5-10 words, so 20 is ~2x headroom for a generous session while
   still bounding a page that has been scribbled over end to end. A settings screen was **not**
   added — there is no settings surface in the app today and CLAUDE.md rule 5 says ask before
   inventing structure. If the cap ever needs to be user-visible, that is its own task.
5. **Contract written down** in `vocab-photo-api/README.md` `## Endpoint`: marked words only, the
   empty array as a valid `200`, and `limit` as a cap with the reading-order drop rule and a pointer
   to D2.

### AC-2 cannot exit 0, and not because of this task

`flutter analyze` reports **5 info-level issues, all of which predate this change** (verified by
stashing the diff and re-running):

- 3x `prefer_const_constructors` — `lib/features/word_input/widgets/word_row_item.dart:62,65,66`
- 2x `depend_on_referenced_packages` for `path_provider` —
  `lib/features/word_input/word_input_screen.dart:8`, `lib/features/words_table/words_table_screen.dart:5`

This diff adds no new analyzer output. Neither group is task-02's: the `const` ones live in a widget
file task-00 split out, and the `path_provider` ones need a `pubspec.yaml` dependency line, which
CLAUDE.md rule 5 puts behind an explicit ask. Left alone deliberately — they belong in a
lint-cleanup pass, or as a follow-up to task-00.

### What still needs a phone

AC-3 (3 highlighted words, 3 pages), AC-4 (nothing highlighted → empty state), AC-5 (over the cap →
first N top-to-bottom), AC-6 (the README `curl` returning non-empty `translation` **and**
`description`) and AC-8 (highlighted Ukrainian / numbers only → empty) are all model-behaviour
tests. The Worker has no test runner, and a unit test here would only assert that a prompt string
contains the word "highlighter" — which AC-1's grep already does. They need a deployed Worker
(`npm run deploy`) and a real device pass. The app side of AC-4 is already in place: the result
dialog renders "No vocabulary words found in this photo." when the list is empty
(`lib/features/word_input/widgets/vocab_result_dialog.dart:55-56`).
