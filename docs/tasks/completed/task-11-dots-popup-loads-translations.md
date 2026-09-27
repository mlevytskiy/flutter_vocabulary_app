# Task 11 — The dots popup shows the translations it already has, and can fetch them

|  |  |
|---|---|
| **Roadmap step** | [#11](../../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 1 (first of the three reported fixes — tasks 12/13 touch the same screen file, so they follow) |
| **Depends on** | — |
| **Blocked on** | — |
| **Unlocks** | task-12 and task-13 (same screen file; serialized by file conflict, not by dependency) |
| **Files** | `lib/features/word_input/widgets/translation_dots_button.dart` · `lib/features/word_input/widgets/translation_options_content.dart` · `lib/features/word_input/word_input_screen.dart` · `lib/features/word_input/widgets/word_row_item.dart` · `docs/lightning_icon_rules.md` |
| **Status** | **code complete 2026-09-23** — AC-1 green (`flutter analyze` 0 issues, `build_runner` wrote no `.g.dart` changes, `flutter test` 36 passing, the three greps clean); AC-2..AC-10 are the device pass and are still unticked. See [Findings](#findings-2026-09-23) |

## The report

> When we click on 3 dots, sometimes I don't see extra translation. Instead of it I see message
> "Tap the lighting icon to load translation." We need to understand why I see the message. If I
> have extra translation, in this case we should show it. If not, we should show "update icon".
> When I clicked on it we should load extra translation.

Two things are asked for: **why** the placeholder appears, and **what** it should do instead.

## Why it appears (from `docs/lightning_icon_rules.md`, "What the popup contains")

Two states reach the popup with no dictionary behind the dots, and both are deliberate in today's
code:

1. **The Word field was edited.** The `wordController` listener clears `_translationOptions[index]`
   on every keystroke in Word (the cached dictionary described the previous word) but deliberately
   leaves `_hasTranslationOptions[index]` alone, so the dots stay solid
   (`word_input_screen.dart:215-218`, and the comment at `:216` names this exact fallback).
2. **The smart-swap path.** `_fillWithAI` sets `_hasTranslationOptions[index] = true` on a real
   translation while setting `_translationOptions[index] = null`, because the English result that
   just landed in Word has no dictionary yet (`word_input_screen.dart:624-627`).

So the message is not a bug in the popup, it is the popup faithfully reporting "the dots are solid
but the cache is empty." The bug is that **the dots' solid state and the cache they describe can
disagree** — `_hasTranslationOptions` is a second, hand-maintained flag that means "a translate
once succeeded for this row", while `_translationOptions` means "here is the block". The first
never hears about the Word-field edit that invalidates the second.

A third gap is adjacent and worth closing in the same change: when the Word field is edited, the
**current translation is not refetched either**, so the row can sit showing a translation for a
word that is no longer in the Word field.

## What it should do instead (decided here)

- **Cache present and non-empty → show the chips.** No placeholder, no request. This already works;
  the point is that it must not be reachable through a state where it does not.
- **Cache absent → show an update icon, and tapping it loads the block.** The icon replaces the
  message as the popup's *body* — a tappable `Icons.refresh` where the placeholder text is today,
  so the popup is never a dead end.
- **The dots must stop lying.** Their solid state must key off the same thing the popup reads, so
  "solid dots" always means "there are chips in here".

The mechanism for the fetch already exists and must be reused, not reinvented:
`GoogleTranslateService.translateWord(word, from: 'en', to: 'uk')` returning the `TranslationResult`
the popup wants, exactly the call `_fillWithAI` already makes (`google_translate_service.dart:88`).

**One consequence to handle deliberately:** `_fillWithAI` *writes* the Translation field with
`translation.best` (`word_input_screen.dart:596`). Reusing it verbatim means tapping the update icon
silently overwrites a translation the user may have edited by hand. Either capture the field's
current text before the call and restore it if the user changed it, or add a fetch-only path that
asks the same service and stores the result without touching the field. Pick one and say which in
the commit message; the acceptance criteria below hold either way.

## Prompt

Read `CLAUDE.md`, `docs/lightning_icon_rules.md` (its "What the popup contains" and "Translation
dots button rule" sections), and this task's "Why it appears" above. One commit. Do not change the
row's height, the dots button's 22px footprint, the popup's size or styling, or any of the three
translate triggers' visibility rules — every change here is about which of two bodies the popup
draws and what its extra tap does.

1. **Make the dots' solid state derive from the cache, not from a parallel flag.** The minimum
   change is to stop reading `_hasTranslationOptions[index]` for the dots and read
   `_translationOptions[index]?.hasDictionary` instead (set either the flag on the same edge or drop
   the flag from this read path — the persisted `WordPair.hasTranslationOptions` field stays where it
   is, so no Isar schema change and no migration). Whatever you pick, the two must not be able to
   disagree.
2. **Keep at least one honest "nothing to show" state.** A row that has never been translated still
   gets no dictionary, so the update icon is also what an untranslated row shows. Confirm the icon is
   not offered on a row whose Word field is empty or shorter than 2 characters — there is nothing to
   ask Google about, and `TextEditingController` text is the only thing it would send.
3. **Wire the icon's tap.** `TranslationOptionsContent` gains an `onLoadTranslations` callback and an
   `isLoading` flag; `translation_dots_button.dart` passes both through from the row. The screen owns
   the actual call (it owns the per-row loading flags and the controllers — rule 2 of
   `docs/architecture.md`), so the popup stays a dumb body. While in flight, show a spinner in the
   popup's body in place of the icon.
4. **Reuse the in-flight state that already exists.** `_isLoadingTranslation[index]` already drives
   the Translation icon's spinner slot; do not add a fourth per-row loading list unless the popup
   needs to stay open across the call in a way this one cannot express.
5. **Handle the failure paths.** A dictionary-less result (Google has no block for this word — a
   phrase, a proper noun) must leave the update icon in place with a short explainer line, not an
   empty popup and not a silent no-op. A thrown request shows the same snackbar shape the rest of
   the screen uses.
6. **`docs/lightning_icon_rules.md`.** Rewrite the "Two cases show a `Tap the lightning icon...`
   placeholder" paragraph to describe the new behaviour, and add a `## Changelog` entry dated for
   this change in the style of the existing entries.
7. **Housekeeping.** If the translated-but-not-refetched gap from "Why it appears" is cheap to close
   in the same edit, close it; if it needs its own decision about when to refetch (on blur? on the
   next dots tap?), write it under `## Open points` instead of guessing.

## Acceptance criteria

- [x] **AC-1** `flutter analyze` exits 0; `dart run build_runner build --delete-conflicting-outputs`
      clean; `flutter test` passes; the three greps in `CLAUDE.md` are clean.
- [ ] **AC-2** On device: translate a row with the Translation lightning, then **edit the Word
      field**. The dots must now reflect reality — either they are empty, or tapping them shows
      chips. The `Tap the lightning icon to load translations.` message must be unreachable from any
      state.
- [ ] **AC-3** On device: after that Word-field edit, tap the dots and then the update icon — the
      popup fetches and shows chips for the **current** Word field content, not the previous one.
- [ ] **AC-4** On device, smart-swap path: type a Ukrainian word into Word, tap the Translation
      lightning (both fields swap), then tap the dots. Either chips appear or the update icon does —
      no placeholder, and the icon loads chips for the English word now in Word.
- [ ] **AC-5** On device: tap the update icon on a row whose Word field is 1 letter or empty — the
      icon is either absent or refuses, and no request is sent with an empty `q`.
- [ ] **AC-6** On device, offline/airplane mode: tapping the update icon fails visibly (snackbar or
      an in-popup line) and leaves the popup usable. It must not hang on a spinner forever and must
      not close itself.
- [ ] **AC-7** On device: pick a chip, close the popup, reopen it — the same chips are still there
      (the cache survived the selection).
- [ ] **AC-8** On device: a hand-edited translation is **not** overwritten by tapping the update
      icon, if the chosen approach restores it; if the chosen approach is fetch-only, this is
      trivially true. State which approach shipped in the commit message.
- [ ] **AC-9** The row's height, the dots button's footprint, the popup's size and the two lightning
      icons' show/hide behaviour are unchanged from before this task.
- [ ] **AC-10** Force-quit and relaunch: a row that had chips restores with either chips or the
      update icon, consistently — not a state that a fresh launch can produce but a restart cannot.

## Open points

- Whether the dots should refetch automatically when the Word field changes, or only on an explicit
  tap. The task takes the tap (it is what the owner asked for); auto-refetch would spend a request
  per keystroke burst.
- Whether the update icon is the right affordance, or the dots should simply go empty again on a
  Word-field edit and let the Translation lightning do the work. The owner asked for the icon.

## Findings (2026-09-23)

Steps 1-6 are implemented. Four notes, the first two deliberate:

1. **The whole `_hasTranslationOptions` list is gone, not just its read path.** Step 1 of the
   prompt allowed either "set the flag on the same edge" or "drop the flag from this read path".
   Both would have left two things meaning one thing, which is the bug being fixed, so the list is
   removed entirely from the screen and the dots derive their state from
   `_translationOptions[index]?.hasDictionary`. The `WordPair.hasTranslationOptions` **field
   stays** — still written by `_pushRow` (derived, never set by hand) and still round-tripped by
   the two tests that assert it — so there is no Isar schema change and no migration.

2. **The fetch writes nothing but the cache.** The prompt said to either restore the user's text
   after a `_fillWithAI` call or add a fetch-only path. It is fetch-only: the call is
   `GoogleTranslateService.translateWord(word, from: 'en', to: 'uk')`, and it is worth noting that
   `translateWord` *itself* writes no fields — the caller does. So the load stores the dictionary
   block and touches neither the Translation field nor the two "filled" marks, and a hand-edited
   translation survives. This is AC-8's second branch.

3. **The popup body is now a `StatefulWidget`.** This is more than the prompt's "add a callback and
   an `isLoading` flag". The popup renders into an overlay, so it cannot rely on the screen's
   `setState` reaching it — it awaits the fetch itself and renders from the result, while the
   screen still owns the request and the storage. The prompt's `isLoading` parameter was therefore
   not needed and is not there.

4. **Empty dots also open the popup now.** They used to be `onPressed: null`. That had to change:
   since the dots go outlined whenever the cache is empty, leaving them inert would have made the
   update icon unreachable from exactly the rows that need it. Outlined versus solid still reads as
   "no chips" versus "chips".

Not verified: AC-2 through AC-10, all of which need a device. The one worth checking first is
AC-5, since `_canLoadTranslationOptions` gates the icon on a trimmed length of 2+ and that
threshold is a choice, not a measurement.
