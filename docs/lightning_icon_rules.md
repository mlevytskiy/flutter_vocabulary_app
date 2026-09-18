# Lightning icon show/hide rules; Translation dots button

This documents the three AI-translate triggers on the word-pair row
(`lib/screens/word_input_screen.dart`):

- **Word icon** (purple `Icons.electric_bolt`): overlaid on the **end
  (right edge) of the Word field**, inside the field's own box. Offers
  translating *Translation → Word*. Gated by focus + a length rule (Rule
  0 and the Word icon rule below) — hidden most of the time.
- **Translation icon** (purple `Icons.electric_bolt`): overlaid on the
  **top-right corner of the Translation field**, inside the field's own
  box. Offers translating *Word → Translation*. Gated by focus + a
  length/"filled" rule (Rule 0 and the Translation icon rule below) —
  hidden most of the time.
- **Translation dots button** (`Icons.circle_outlined` / `Icons.circle`):
  sits **outside** the Translation field entirely, as its own element to
  the field's right — not overlaid, not gated by focus. **Always
  visible.** Its full/solid state is the sole way to open the "more
  options" popup — see the Translation dots button rule below.

The Word icon and Translation icon are symmetric siblings (same focus
gate, same overlay style, mirrored positioning). The dots button is
independent and asymmetric on purpose — see history in the Changelog.

## Rule 0 — focus gate (Word icon and Translation icon)

**A lightning icon can only be visible while its row is "in focus."** If
neither the Word field nor the Translation field of a row currently has
focus, both of that row's icons are hidden, regardless of the rules
below. As soon as the row gains focus (either field), the icons follow
their own rules normally. Losing focus (tapping away, moving to another
row, dismissing the keyboard) immediately hides both icons again.

This gate does **not** apply to the Translation dots button — it is
always rendered, focused row or not.

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

Tapping it runs `_fillWordWithAI` (Translation → Word, any source
language auto-detected via Google Translate's `from: 'auto'`), with its
own loading spinner (`_isLoadingWordTranslation`) shown in the same spot
while the request is in flight.

## Translation icon rule

Show the Translation icon iff, in addition to Rule 0:

- **Word has 2+ letters**, **and**
- **Translation is NOT yet "filled"** — see the "Translation filled"
  definition below.

```
translationIsFilled = translation.length > 5 || translationMarkedFilled
showTranslationIcon  = isItemFocused && wordHasTwoLetters && !translationIsFilled
```

The loading spinner that can occupy this same corner is governed
separately (unaffected by this rule). Unlike the pre-dots-button design,
there is no amber "more options" state for this icon anymore — it is
always the plain purple `electric_bolt`; opening the popup is the dots
button's job now (see below).

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

A successful translate action — whether the plain English → Ukrainian run
or the smart-swap path — sets `_hasTranslationOptions[index] = true`,
which is what turns the Translation dots button solid (see below). The
smart-swap path sets it too (not just the plain path): a real translation
there still means there's more to offer than the literal swap, e.g.
translation-in-context alternatives.

## Translation dots button rule

The dots button has no show/hide rule of its own — it is always rendered,
for every row, regardless of focus. Its **appearance** and **tap
behaviour** both key off `_hasTranslationOptions[index]`:

- **Empty dots** (`Icons.circle_outlined`, purple) — the default, i.e.
  `_hasTranslationOptions[index] == false`. Tapping does **nothing**
  right now (`onPressed: null`) — there is currently no action wired to
  this state.
- **Full dots** (`Icons.circle`, purple — same color as empty) — shown once
  `_hasTranslationOptions[index] == true`, i.e. once the Translation
  icon's action (either the plain English → Ukrainian run, or the
  smart-swap path — see below) has produced a real translation for this
  row. Tapping opens the "more options" popup
  (`_selectTranslationOption` per picked option).

### What the popup contains

The popup shows **Google's dictionary block for the Word field** —
every translation Google knows for that word, grouped by part of speech
in priority order (noun, verb, adjective, adverb, then any other group),
each word a tappable chip that fills the Translation field
(`lib/features/word_input/widgets/translation_options_content.dart`).

That data is **not a second request**: the English → Ukrainian translate
asks for the dictionary in the same call it uses to fill the Translation
field (`dt=t&dt=bd&dt=at`, see `GoogleTranslateService`) and the whole
`TranslationResult` is kept in `_translationOptions[index]` for the
popup. Opening the popup never touches the network.

Two cases show a `Tap the lightning icon to load translations.`
placeholder instead of chips, because the dots are solid without a
dictionary behind them:

- the **smart-swap path** — it sets `_hasTranslationOptions` on a real
  translation but has no dictionary for the *new* Word field content;
- **after the Word field is edited** — `_translationOptions[index]` is
  dropped on every keystroke in Word (the old dictionary described the
  previous word), while the dots deliberately stay solid.

The dots button has **no loading state of its own** — while a translate
request is in flight (`_isLoadingTranslation[index] == true`), the dots
simply stay in whatever state they were already in (empty or full) and
flip only once the request resolves and `_hasTranslationOptions` changes.
The loading spinner itself is shown separately, in the Translation icon's
own overlay slot (see "Translation icon rule" above).

## Successful-translation marking rule

Whenever either translate action (the Word icon's Translation→Word, the
Translation icon's Word→Translation, or the Translation icon's smart
swap above) **produces a real translation** — not just an echo of the
input — **both** fields of that row are marked "filled"
(`_wordMarkedFilled` and `_translationMarkedFilled`), not only the field
that got written to.

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
| Item in focus | Either the Word field or the Translation field of this row currently has focus — gates the Word icon and Translation icon (Rule 0); does not gate the dots button |
| Word ≥2 letters | `Word field` text length is 2 or more — triggers the Translation icon (see above) |
| Translation ≥2 letters | `Translation field` text length is 2 or more — triggers the Word icon (see above); independent of "Translation filled" below |
| Word fully empty | `Word field` text is empty (0 characters) |
| Translation filled | `Translation field` text length is more than 5, **or** it was populated automatically (AI translate, picking a popup translation option, or photo recognition) — hides the Translation icon (see above) |
| Word filled | `Word field` text length > 5, **or** it was populated automatically (photo recognition, or a real translation via the Word icon — see "Successful-translation marking rule" above). Tracked in `_wordMarkedFilled`, but not currently wired to either icon's visibility |
| Translation has options | `_hasTranslationOptions[index]` — drives the Translation dots button's empty/full state and its popup |

Note the two overlaid icons are **not symmetric in their thresholds**:
the Word icon's own trigger ("Translation ≥2 letters") is intentionally a
lower bar than the Translation icon's hide condition ("Translation
filled", >5 or auto-populated). In the 2–5-character range, if Word is
empty, only the Word icon shows (Translation icon requires Word to have
2+ letters, so the two can never show at once for the same row — see
worked example below).

### Worked example (why the two overlaid icons never overlap)

| Word text | Translation text | Show Word ⚡ | Show Transl ⚡ | Why |
|---|---|---|---|---|
| *(empty)* | *(empty)* | − | − | Translation <2 letters |
| *(empty)* | `hi` (2) | + | − | Word empty + Transl ≥2; Transl icon needs Word ≥2 (it's empty) |
| *(empty)* | `hello!` (6) | + | − | Same as above — Word icon doesn't care about "filled", only ≥2 |
| `a` (1) | `hello!` (6) | − | − | Word not empty (so Word icon hides) and not ≥2 either (so Transl icon can't show) |
| `an` (2) | `hi` (2) | − | + | Word ≥2, Translation not yet filled |
| `an` (2) | `hello!` (6) | − | − | Word ≥2 but Translation is filled → Transl icon hides too |

(All rows assume the row is focused, per Rule 0. The dots button's
empty/full state is independent of this table — it depends only on
`_hasTranslationOptions`.)

## Implementation notes

- **Word icon position:** placed at the end (right edge) of the Word
  field, 2px inset — the same padding the Translation icon uses at the
  end of the Translation field. Because both fields live in one `Stack`
  spanning the whole row (via `SyncedTextFieldRow`), the Word field's
  right edge isn't the Stack's right edge, so its `Positioned` is
  computed from the row's measured width (`LayoutBuilder`) rather than a
  fixed `right:` value.
- **Translation icon position:** `Positioned(top: 2, right: 2)` inside
  the same `Stack`, pinned to the Stack's own right edge (which coincides
  with the Translation field's right edge).
- **Translation dots button position:** sits *outside* that `Stack`, as a
  plain sibling in the outer `Row` (after the `Expanded` that wraps the
  Word/Translation fields), so it never overlaps the Translation field's
  own box — it just takes its own slice of the row's width, immediately
  to the field's right. Built by `_buildTranslationDotsButton(index)`.
  The outer `Row` uses `crossAxisAlignment: CrossAxisAlignment.center` so
  the (much shorter) dots button sits vertically centered against the
  fields rather than pinned to their top.
- **Dots button sizing:** three 6px dots (3px gap) inside a `SizedBox`
  22px wide, tapped via an `IconButton` with `padding: EdgeInsets.zero`,
  empty `constraints`, and `VisualDensity.compact` — the same tight-button
  pattern the row's own delete ("X") button uses — instead of the default
  `IconButton`'s 48px minimum tap target, so it claims as little of the
  row's horizontal space as possible. The full (`CustomPopupMenu`) variant
  uses the same 22px-wide `SizedBox` with the dots centered inside via
  `Center` (no extra padding), matching the empty variant's footprint
  exactly — so flipping `_hasTranslationOptions` between the two never
  shifts the row's layout.
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

## Changelog

- **2026-09-01:** Original implementation — both the Word icon and the
  Translation icon (purple `electric_bolt`, turning into an amber
  `electric_bolt` popup trigger once `_hasTranslationOptions` was true)
  lived overlaid inside the Stack, both gated by Rule 0 + their own
  length thresholds. Full history of that build (the successful-
  translation marking rule, the smart language swap, the focus-node
  refactor, etc.) is preserved in this repo's commit history — see the
  commit titled "add implementation hide/show lightning button and cover
  each cases connected to the button".
- **2026-09-01 (later):** Experimented with replacing the Translation icon
  entirely with an always-visible button outside the field (first a
  lightbulb, then three dots), with various trial rules for its
  empty/full state and tap behaviour.
- **2026-09-01 (final):** Reverted the Translation icon to its original
  overlaid, focus-gated, purple-only behaviour (this doc's "Translation
  icon rule" above) — the experiment's amber popup-trigger variant is
  gone. Kept the always-visible Translation dots button from the
  experiment as an *additional*, independent control: it no longer has
  its own amber "icon" identity, it's purely the popup trigger — full
  (solid) dots open the same "more options" popup the amber icon used to
  open, empty dots remain a no-op. The two overlaid icons (Word,
  Translation) and the outside dots button now coexist as three
  independent controls per row.
- **2026-09-01 (later still):** Removed the dots button's own loading
  spinner (it used to replace the dots with a `CircularProgressIndicator`
  while `_isLoadingTranslation` was true). The dots now simply hold their
  current empty/full state during a translate request and flip straight
  to full once it resolves — the loading spinner is shown once, in the
  Translation icon's own overlay slot, not duplicated in the dots.
- **2026-09-01 (later still):** The smart-swap path now sets
  `_hasTranslationOptions[index] = true` on a real translation, same as
  the plain English → Ukrainian path — it previously cleared this flag,
  which hid the dots button after a swap. Typing a Ukrainian word
  directly into Word (triggering the swap) now also surfaces the dots'
  "more options" popup, not just the Word/Translation swap itself.
- **2026-09-01 (later still):** Full (solid) dots changed from amber to
  purple, matching the empty (outlined) dots and the two lightning icons
  — the dots button no longer has an amber state at all.
- **2026-09-18:** The popup stopped showing placeholder strings. The
  English → Ukrainian translate now goes through
  `lib/core/services/google_translate_service.dart`, which asks Google's
  `translate_a/single` for the dictionary block and the ranked
  alternatives in the same request, **picks the Translation field's value
  out of that set by part of speech** (noun first, then verb, adjective,
  adverb; for a noun group with no ranked match the word is re-asked as
  `the <word>`) instead of taking Google's single one-line answer, and
  hands the same set to the dots popup — see "What the popup contains"
  above. The `translator` package is no longer used by the screen (all
  three translate calls go through the service); it stays in `pubspec.yaml`.
