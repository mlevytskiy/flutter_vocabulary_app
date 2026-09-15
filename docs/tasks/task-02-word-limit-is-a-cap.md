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
| **Status** | not started |

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

- [ ] **AC-1** `grep -in highlight vocab-photo-api/src/index.ts` matches the prompt builder.
- [ ] **AC-2** `cd vocab-photo-api && npm run typecheck` exits 0; `flutter analyze` exits 0.
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
- [ ] **AC-7** `grep -n "'false'" lib/services/vocab_photo_service.dart` returns no matches.
- [ ] **AC-8** A photo with highlighted **Ukrainian** text, or highlighted numbers only, returns an
      empty array rather than guesses.
