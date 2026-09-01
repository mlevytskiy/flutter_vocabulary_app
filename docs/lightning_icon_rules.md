# Lightning icon show/hide rules

This documents when the amber/purple "lightning" (`Icons.electric_bolt`)
trigger icons on the word-pair row (`lib/screens/word_input_screen.dart`)
should be shown or hidden. There are two such icons on a row:

- **Word icon** (new): sits at the **end (right edge) of the Word field**
  (same padding as the Translation icon's edge placement — see
  Implementation notes below). Offers translating *Translation → Word*.
- **Translation icon** (existing): sits in the top-right corner, over the
  *Translation* field. Offers translating *Word → Translation*.

Out of scope for this doc: the amber "more translation options" popup that
replaces the Translation icon once a translation has been fetched, and the
loading spinner shown while a translation request is in flight. Both keep
their existing behaviour untouched — they're a separate concern from "when
does the trigger icon appear".

## Rule 0 — focus gate (applies to both icons, before anything else)

**A lightning icon can only be visible while its row is "in focus."** If
neither the Word field nor the Translation field of a row currently has
focus, both of that row's icons are hidden, regardless of the rules below.
As soon as the row gains focus (either field), the icons follow their own
rules normally. Losing focus (tapping away, moving to another row,
dismissing the keyboard) immediately hides both icons again.

## Word icon rule

Show the Word icon iff, in addition to Rule 0:

- **Word field is fully empty** (0 characters — not merely "short"; any
  typed character hides it), **and**
- **Translation has 2+ letters.**

This threshold is deliberately lower than Translation's own "filled"
concept below — showing the Word icon only needs enough Translation text
to make a reverse translation worth trying, not a full commitment to
typing manually.

```
showWordIcon = isItemFocused && wordIsFullyEmpty && translation.length >= 2
```

## Translation icon rule

Show the Translation icon iff, in addition to Rule 0:

- **Word has 2+ letters**, **and**
- **Translation is NOT yet "filled"** — see the "Translation filled"
  definition below.

```
translationIsFilled = translation.length > 5 || translationMarkedFilled
showTranslationIcon  = isItemFocused && wordHasTwoLetters && !translationIsFilled
```

The loading spinner and the amber "more options" popup that can occupy
this same corner are governed separately (unaffected by this rule).

### Translation icon action — smart language swap

`_fillWithAI` (the Translation icon's action, Word → Translation) first
looks at just the **first letter** of the Word field:

- **First letter is an English letter (A-Z/a-z):** behaves exactly as
  before — translates Word (English) to Translation (Ukrainian) and fills
  the Translation field, as documented above.
- **First letter is not an English letter:** the Word field probably holds
  what should have been the Translation (typed into the wrong field) —
  e.g. the user typed a Ukrainian word directly into Word. Instead of
  translating English → Ukrainian (which would produce nonsense from
  non-English input), this auto-detects the Word field's language and
  translates it to English. If that produces a **real translation** (see
  "Successful-translation marking rule" below), the two fields are
  **swapped**: the text the user originally typed moves to Translation,
  and the English result moves to Word. If it doesn't (an echo, or the
  request fails), neither field is touched and a snackbar reports it —
  same as the request-failure case.

This is a first-letter heuristic, not a full language check — a Word field
that starts with an English letter but contains other-language text past
that point still takes the plain English → Ukrainian path.

## Successful-translation marking rule

Whenever either translate action (the Word icon's Translation→Word, the
Translation icon's Word→Translation, or the Translation icon's smart
swap above) **produces a real translation** —
not just an echo of the input — **both** fields of that row are marked
"filled" (`_wordMarkedFilled` and `_translationMarkedFilled`), not only the
field that got written to.

"Real translation" means the (trimmed) output differs from the (trimmed)
input. Google Translate — via the `translator` package both actions use —
doesn't signal failure when it has no translation for the input; it
silently echoes the input text back unchanged instead. That's observable
in the app as "I asked for a translation and got my own word back." When
that happens, neither field is marked filled — the field that received the
echoed text still only counts as "filled" via the plain length rule
(`_isTranslationFilled`'s `length > 5` half), same as if the user had typed
it by hand.

```
gotRealTranslation = output.trim() != input.trim()
// on success, if gotRealTranslation:
wordMarkedFilled        = true
translationMarkedFilled = true
```

Implemented via the shared `_isRealTranslation(input, output)` helper,
called from both `_fillWithAI` and `_fillWordWithAI`. Picking a popup
translation option (`_selectTranslationOption`) and photo recognition
(`_addWordsFromPhoto`) mark only the field they directly populate, since
there's no "other field" input to compare against in those paths.

## Terms

| Term | Meaning |
|---|---|
| Item in focus | Either the Word field or the Translation field of this row currently has focus |
| Word ≥2 letters | `Word field` text length is 2 or more |
| Translation ≥2 letters | `Translation field` text length is 2 or more — triggers the Word icon (see above); independent of "Translation filled" below |
| Translation filled | `Translation field` text length is more than 5, **or** it was populated automatically (AI translate, picking a popup translation option, or photo recognition) — hides the Translation icon (see above) |
| Word filled | `Word field` text length > 5, **or** it was populated automatically (photo recognition, or a real translation via the Word icon — see "Successful-translation marking rule" above). Tracked in `_wordMarkedFilled`, but not currently wired to either icon's visibility — see Implementation status |
| Word fully empty | `Word field` text is empty (0 characters) |

Note the two icons are **not symmetric**: the Word icon's own trigger
("Translation ≥2 letters") is intentionally a lower bar than the
Translation icon's hide condition ("Translation filled", >5 or
auto-populated). In the 2–5-character range, if Word is empty, only the
Word icon shows (Translation icon requires Word to have 2+ letters, so the
two can never show at once for the same row — see worked example below).

Previously-open question, now resolved for **both** fields: once a field
is marked "filled" by auto-population, that status persists through edits
and only clears when the field is emptied completely (mirrors the existing
`_hasTranslationOptions` reset behaviour). Implemented in
`_translationMarkedFilled` and `_wordMarkedFilled`. Word's flag still
doesn't gate either icon's visibility today (see Implementation status) —
only the state is tracked so far.

### Worked example (why the icons never overlap)

| Word text | Translation text | Show Word ⚡ | Show Transl ⚡ | Why |
|---|---|---|---|---|
| *(empty)* | *(empty)* | − | − | Translation <2 letters |
| *(empty)* | `hi` (2) | + | − | Word empty + Transl ≥2; Transl icon needs Word ≥2 (it's empty) |
| *(empty)* | `hello!` (6) | + | − | Same as above — Word icon doesn't care about "filled", only ≥2 |
| `a` (1) | `hello!` (6) | − | − | Word not empty (so Word icon hides) and not ≥2 either (so Transl icon can't show) |
| `an` (2) | `hi` (2) | − | + | Word ≥2, Translation not yet filled |
| `an` (2) | `hello!` (6) | − | − | Word ≥2 but Translation is filled → Transl icon hides too |

(All rows assume the row is focused, per Rule 0.)

## Implementation notes

- **Word icon position:** placed at the end (right edge) of the Word field,
  2px inset — the same padding the Translation icon uses at the end of the
  Translation field. Because both fields live in one `Stack` spanning the
  whole row (via `SyncedTextFieldRow`), the Word field's right edge isn't
  the Stack's right edge, so its `Positioned` is computed from the row's
  measured width (`LayoutBuilder`) rather than a fixed `right:` value.
- **Focus tracking:** every row has its own `FocusNode` for both fields
  (`_wordFocusNodes[index]`, `_translationFocusNodes[index]`, created in
  `_addControllersForIndex`), each with a listener that rebuilds the UI on
  focus change. Nodes are disposed in `_removeItem` (full removal) and in
  `dispose()`, and moved alongside every other per-row list in
  `_reorderItems`.
- **Hot-reload safety net:** `_ensureRowStateSynced()`, called at the top
  of `build()`, pads any per-row list (focus nodes, `_translationMarkedFilled`)
  that fell behind `_wordControllers.length` — this only happens after a
  hot reload adds a new per-row field, since hot reload doesn't re-run
  `initState()` on the already-live State object. No-ops in release builds
  (`kReleaseMode` check) since hot reload can't happen there; a normal
  cold launch never triggers it either since the lists are already in
  sync.

## Implementation status

- **Done:** show/hide logic for both icons, including the focus gate, the
  split Word-icon/Translation-icon thresholds, and the "auto-populated"
  half of "Translation filled". Word icon positioned at the end of the
  Word field (2px inset), matching the Translation icon's positioning at
  the end of the Translation field. The Word icon's action
  (`_fillWordWithAI`) is now implemented: translates the Translation
  field's text (any source language, auto-detected) to English and fills
  the Word field, with its own loading spinner
  (`_isLoadingWordTranslation`) shown in the same spot while the request
  is in flight. The Translation icon's existing behaviour (calls Google
  Translate, shows its own loading spinner, then the amber multi-option
  popup) is unchanged.
- **Done:** `_wordMarkedFilled` tracking, per the "Successful-translation
  marking rule" above — both fields get marked filled together on a real
  translation (checked via `_isRealTranslation`), whichever direction the
  translate action ran. Photo recognition also marks the Word field filled
  (`_addWordsFromPhoto`), matching the pre-existing Translation handling.
- **Not implemented:** wiring "Word filled" into either icon's visibility
  rule. Nothing currently reads `_wordMarkedFilled` (or the Word field's
  `length > 5`) for show/hide purposes — the Word icon still hides purely
  because filling it makes "Word fully empty" false, which happens to
  produce the same visible result today. Implement an `_isWordFilled(index)`
  helper (mirroring `_isTranslationFilled`) if/when a future rule needs to
  distinguish "Word filled" from "Word non-empty".

## Changelog

- **2026-09-01:**
  - Translation icon's hide threshold changed from "2+ letters" to
    "filled" (more than 5 characters), to match the Word field's own
    "filled" concept — the old 2-letter threshold was hiding the icon too
    early.
  - "Translation filled" extended to also cover auto-population (AI
    translate, picking a popup option, photo recognition), matching "Word
    filled"'s definition. Backed by a new `_translationMarkedFilled`
    per-row flag, wired into the same add/remove/reorder/reset lifecycle
    as the existing per-row lists.
  - Word icon position moved from the top-left corner of the Word field to
    its end (right edge), to match the Translation icon's placement
    pattern.
  - Added the "item in focus" rule (Rule 0): both icons on a row are
    hidden whenever neither field of that row has focus. Backed by new
    per-row `_wordFocusNodes` / `_translationFocusNodes`, replacing the
    old single `_firstFieldFocusNode` (which only ever handled row 0's
    launch autofocus).
  - Added `_ensureRowStateSynced()` (hot-reload-only, no-op in release
    builds) to fix a `RangeError` new per-row list fields would otherwise
    hit on hot reload.
  - **Un-merged the Word icon's trigger from Translation's "filled"
    concept.** The Word icon now shows again once Translation reaches 2+
    letters (not 5+) — this was the pre-existing, never-changed rule for
    the Word icon specifically; only the *Translation icon's own hide*
    threshold was ever meant to move to 5. The two icons' thresholds are
    intentionally different numbers now (documented in the "Terms" note
    above and the worked example) and this does not reintroduce any
    overlap between the two icons.
  - **Implemented the Word icon's action.** Tapping it now translates the
    Translation field's text to English and fills the Word field, using
    the `translator` package's auto-detect source language support
    (`from: 'auto'`) — Google Translate (which the package scrapes)
    auto-detects across its full supported-language list, so any language
    typed into Translation works, not just a fixed set. Added a dedicated
    `_isLoadingWordTranslation` per-row flag (mirroring
    `_isLoadingTranslation`) so the Word icon's own loading spinner
    doesn't interfere with the Translation icon's.
  - **Added the successful-translation marking rule.** Either translate
    action now marks *both* fields "filled" (`_wordMarkedFilled` +
    `_translationMarkedFilled`) when it gets a real translation back, via
    a new shared `_isRealTranslation(input, output)` heuristic (output
    differs from input after trimming). This also documents and works
    around an observed API/library behaviour: when there's no translation
    available, Google Translate silently echoes the input back instead of
    signalling failure, so a naive "non-empty result" check would have
    wrongly marked fields "filled" on a no-op echo.
  - **Added the Translation icon's smart language swap.** `_fillWithAI`
    now checks the Word field's first letter: if it's not an English
    letter, it auto-detects the Word field's language, translates to
    English, and — only on a real translation — swaps the two fields
    (typed text -> Translation, English result -> Word) instead of
    running the plain English -> Ukrainian path. Added `_isEnglishLetter`
    as the first-letter check.
