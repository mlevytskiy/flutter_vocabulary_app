# Task 19 — A Settings option to show a definition instead of (or beside) the translation

|  |  |
|---|---|
| **Roadmap step** | [#14](../../roadmap.md#steps) (the build half of step 9, now that D3 picked the source) |
| **Size** | L (three subtasks, one commit each) |
| **Wave** | 9 (after task-13: same screen file, and it adds the second row to task-13's Settings screen) |
| **Depends on** | **task-13** (the Settings screen and its provider pattern) · **task-18** (D3 → Merriam-Webster) |
| **Blocked on** | **D10** — where the Merriam-Webster key lives and who calls the API (see below; the task proceeds on the recommendation) |
| **Unlocks** | a follow-up for what the words table, the AnkiDroid export and the shared page do with definitions (see [Open points](#open-points)) |
| **Files** | `lib/core/providers.dart` · `lib/features/settings/settings_screen.dart` · `lib/features/word_input/widgets/word_row_item.dart` · `lib/features/word_input/word_input_screen.dart` · `lib/core/models/word_pair.dart` (+ `.g.dart`) · `lib/core/services/dictionary_service.dart` (new) · `lib/config/vocab_api_config.dart` · `docs/lightning_icon_rules.md` · `docs/architecture.md` |
| **Status** | **todo** — planned only. Nothing is implemented yet, on the owner's instruction |

## The report

> our next step will be plan option in settings screen to use definishion instead of translation.
> Probably we should have 3 option: use translation, use definishion, use translation and
> definishion. When we use definishion we should field under the word field (vertical orientation)
> because definishion usualy bigger than translation and used horizontal layout will be not
> convinient, when we pick definishion we should hide translation field and use simular way of
> showing definishion field. First we shouldn't implement this all. We should create task for that

It asks for three things: a three-way preference, a new field that fills the way Translation fills,
and a vertical layout whenever that field is showing.

| Mode | Row layout | Fields visible |
|---|---|---|
| **Translation** (default, today) | Word \| Translation side by side, **unchanged pixel for pixel** | Word, Translation |
| **Definition** | Word on top, full width; Definition **under it**, full width | Word, Definition. Translation is hidden |
| **Translation + definition** | today's Word \| Translation row, then Definition full width **under it** | Word, Translation, Definition |

The owner didn't describe the layout for "both" in so many words. The reading above keeps
today's row as it is and adds the definition underneath. That follows their reasoning that a
definition is too long to sit side by side with anything.

## What is already there

- **Settings screen** (task-13): `lib/features/settings/settings_screen.dart` has one
  `SwitchListTile` bound to `dragModeProvider`. That is a `@Riverpod(keepAlive: true)` notifier in
  `lib/core/providers.dart`, a display preference that never reaches Isar. The new option follows
  the same pattern.
- **The row** is `WordRowItem` (`word_row_item.dart`, 281 lines). Its two fields are one
  `SyncedTextFieldRow` (`lib/core/widgets/synced_text_field_row.dart`), a widget built only for
  *two side-by-side fields of equal height*. The row lays out several things from the Word field's
  right edge, computed as half the fields area: the pronunciation flags in the top strip, the
  Word lightning icon, and the Translation lightning icon at the stack's right edge. A full-width
  Word field changes that arithmetic. It does not just need a different widget.
- **How Translation fills** (the "similar way" the owner means): a purple `Icons.electric_bolt`
  overlaid on the field's top-right corner, gated by focus plus a length rule
  (`docs/lightning_icon_rules.md`). Tapping it runs `_fillWithAI` (`word_input_screen.dart:680`),
  which shows a spinner in place of the icon and writes the result into the controller. The screen
  keeps parallel per-row lists: controllers, focus nodes, `_isLoading…` flags and `…MarkedFilled`
  flags (`word_input_screen.dart:51` onwards). A Definition field needs one more of each.
- **Storage:** `WordPair` (`lib/core/models/word_pair.dart`) is `@embedded` in `Session` (Isar). It
  has `word`, `translation`, `translationOptionsJson` and the two `…MarkedFilled` flags. It has
  **no definition field**. `isValid` is `word && translation`.
- **Source:** D3 closed on the **Merriam-Webster Collegiate API**
  (`investigations/dictionary-apis/`). One GET per word, `shortdef[]` holds the short senses, and
  the median response was ~156 ms in the probe. An unknown word comes back as a list of
  spelling-suggestion *strings*, not entries. The adapter at
  `investigations/dictionary-apis/src/providers/merriam-webster.mjs` shows the parsing, including
  "keep only entries whose `meta.id` matches the headword".
- **Keys:** `lib/config/vocab_api_config.dart` holds `baseUrl` and `appSecret`. CLAUDE.md rule 4 says
  this file is gitignored, but **it is tracked**: `git ls-files` lists it, and its line in
  `.gitignore` is commented out (`#lib/config/vocab_api_config.dart`). A Merriam-Webster key added
  there would be committed. This is why D10 exists.

## Blocked on D10

> Who calls Merriam-Webster, and where does its key live?
>
> - **(a) The device calls Merriam-Webster directly.** The key is a constant in
>   `vocab_api_config.dart` (rule 4). This is the smallest change: one `http` GET, no Worker
>   change and no deploy. The key ships inside the APK. So does `appSecret` today, and the free
>   tier is non-commercial at 1,000 calls/day anyway.
> - **(b) The Worker gets a `/define` route**, and the key is a `wrangler secret`. The key never
>   leaves Cloudflare, and the Worker can cache definitions. The cost is a Worker change, a deploy,
>   and a second hop on every lookup.

**Recommended: (a)**, *but* resolve the tracked-file problem first. Either untrack
`vocab_api_config.dart` (uncomment the `.gitignore` line, `git rm --cached`, and commit a
`vocab_api_config.example.dart`), or accept that this key is committed. That choice belongs to the
owner, and this task must not make it silently. Record the answer as **D10** in
`docs/roadmap.md` before subtask B starts. If the answer is (b), subtask B's service calls the
Worker instead, and the Worker route becomes its own task.

## Prompt

Read `CLAUDE.md`, `docs/architecture.md`, `docs/lightning_icon_rules.md`, task-13 (the provider
pattern and the Settings screen), and the Findings in `investigations/dictionary-apis/README.md`.
Three subtasks, **one commit each**, in this order. Each one leaves the app working.

### A — The preference and the Settings row (no layout change yet)

1. **`WordDetailMode`**: an enum `{ translation, definition, both }` next to the notifier in
   `lib/core/providers.dart`, plus a `@Riverpod(keepAlive: true)` notifier defaulting to
   `translation`. Like `dragModeProvider`, it never goes on `Session` and never reaches Isar.
   **It does survive a relaunch**: read and write it through `shared_preferences`, which is already
   a dependency and already stores `current_session_id`. This is a real preference, unlike drag
   mode. Rule 5 still holds: no new packages.
2. **Settings row:** under the drag-and-drop switch, one titled group with three `RadioListTile`s:
   `Translation`, `Definition`, `Translation + definition`. No new screen and no dialog. The screen
   was built to take more rows.
3. No reader yet. The input screen is untouched in this commit.

### B — Where a definition comes from, and where it is kept

4. **`WordPair.definition`**: a `String` defaulting to `''`, plus `definitionMarkedFilled`. Wire both
   through `fromJson`, `toJson` and `copy`. This adds fields to an existing embedded object, which
   is not a new domain model (rule 5). Adding a field with a default is a non-breaking Isar change,
   but still rerun `build_runner` and confirm an existing session opens with every definition
   empty. **Switching mode never deletes data**: a hidden translation or definition stays stored.
5. **`DictionaryService`** in `lib/core/services/dictionary_service.dart`, exposed through a provider
   in `providers.dart` (rule 2). It has one method, `Future<DefinitionResult?> define(String word)`,
   and uses `http`, which is already a dependency. Parse the way the investigation's adapter does:
   keep entries whose `meta.id` (before `:`) equals the word, fall back to all entries, and take
   `shortdef`. An unknown word returns the suggestion strings rather than throwing. The key and
   endpoint follow D10. Keep `DefinitionResult` a plain Dart class next to the service, like
   `translation_result.dart`.
6. **What goes into the field**: the first `shortdef` of each matching entry, with at most three
   senses, numbered `1. … 2. …` on separate lines. The field is multi-line, so the text stays
   readable, and editable. An unknown word leaves the field empty and shows a `SnackBar`:
   "No definition found — did you mean: …", listing the suggestions. It never writes a suggestion
   into the field by itself.

### C — The rows follow the mode

7. **Translation mode is untouched.** The existing `SyncedTextFieldRow` path, the constants and the
   icon positions stay byte for byte. Branch around them. Do not rewrite them (rule 3).
8. **Definition mode:** Word full width, with a Definition field under it, also full width and
   multi-line (`minLines: 2`, `maxLines: null`). The Translation field, its lightning icon and its
   dots button are **not built**. The pronunciation flags move to the full-width Word field's right
   edge, which is the same rule as today with a different width. The Word lightning icon
   (Translation → Word) is hidden: there is no Translation to translate from.
9. **Both mode:** today's Word | Translation row exactly as it is, then the Definition field full
   width under it.
10. **The Definition field's lightning icon** copies the Translation icon: overlaid top-right,
    shown only while the row has focus (Rule 0), with a spinner while loading. Tapping it calls
    `DictionaryService.define(word)`. Its show rule mirrors the Translation icon rule. Write it into
    `docs/lightning_icon_rules.md` as **"Definition icon"**, with the same focus gate. The
    definition has no dots popup. Merriam-Webster's other senses are an open point, not this task.
11. **Per-row state:** add a definition controller, focus node, `_isLoadingDefinition` and
    `_definitionMarkedFilled` to the screen's parallel lists, in the same places the Translation
    ones are created, restored, reordered, removed and pushed (`_addControllersForIndex`,
    `_restoreFromStore`, `_reorderItems`, `_removeItem`, `_pushRow`). The Definition focus node
    counts toward "the row is in focus".
12. **Row validity follows the mode.** `WordPair.isValid` requires a translation, so a
    definition-only row would never count. Make validity mode-aware in the one place the screen
    uses it: word plus translation, word plus definition, or word plus either one. Keep the
    getter's meaning for other callers.
13. **Photo capture:** words from a photo still arrive with the Worker's translation, stored and
    hidden in definition mode. No definition is fetched automatically. A photo of 30 words must not
    make 30 Merriam-Webster calls behind the owner's back. The lightning icon is the only trigger.
14. **`docs/architecture.md`**: the Settings node gains the edge to `wordDetailModeProvider`, and
    the services list gains `DictionaryService`.

## Acceptance criteria

- [ ] **AC-1** `dart run build_runner build --delete-conflicting-outputs` is clean, `flutter test`
      passes, and the three greps in `CLAUDE.md` are clean. `flutter analyze` adds **no new** issue.
      The nine pre-existing infos from task-13's Findings may remain.
- [ ] **AC-2** Settings shows three options with **Translation** selected on a fresh install. The
      chosen option survives an app relaunch.
- [ ] **AC-3** In **Translation** mode the input screen is visually identical to before this task:
      same row heights, flag positions, icon positions and dots button. A screenshot comparison on
      one device is enough.
- [ ] **AC-4** In **Definition** mode every row shows Word on top and Definition underneath, both
      full width. No Translation field, no dots button and no Word lightning icon. The flags sit at
      the Word field's right edge.
- [ ] **AC-5** In **Translation + definition** mode each row is today's Word | Translation row
      with a full-width Definition field under it.
- [ ] **AC-6** With the row focused and a word typed, the Definition lightning icon appears and
      shows a spinner while loading. For `tenacious` it fills the field with numbered short senses
      from Merriam-Webster.
- [ ] **AC-7** For `determinated` the field stays empty and a `SnackBar` offers the suggestions,
      *determined* among them. Nothing is written into the field.
- [ ] **AC-8** Switching modes back and forth never loses data. A translation typed in Translation
      mode is still there after a round trip through Definition mode, and the same holds for a
      definition.
- [ ] **AC-9** Definitions survive a relaunch, and an existing session from before this task opens
      with empty definitions and no errors.
- [ ] **AC-10** In Definition mode a row with a word and a definition but no translation counts as
      filled. The auto-added empty row appears after it, and it is not treated as incomplete.
- [ ] **AC-11** Taking a photo in Definition mode makes **zero** Merriam-Webster calls.
- [ ] **AC-12** The Merriam-Webster key is wherever D10 says, and it appears in **no** file
      `git ls-files` lists unless the owner explicitly accepted that under D10.

## Open points

- **Words table, AnkiDroid export, shared page.** All three read `word` and `translation` only
  (`words_table_screen.dart:307`, `anki_export.dart:32`, `vocab-photo-api/src/session/*`). What they
  do with a definition is a follow-up task: a third column, a mode-dependent back of the card, or
  "the definition replaces the translation when there is no translation". Until then a definition is
  on the device only.
- **More senses.** Merriam-Webster often returns 5–14 short senses. A dots-style popup to pick a
  different sense, like the translation popup, would be a natural next step. It is left out to keep
  this task's surface bounded.
- **British audio.** Merriam-Webster has American audio only. On-device TTS (D1) stays the
  pronunciation source, so nothing about the flags changes.
- **Free-tier terms.** The key is non-commercial, 1,000 calls/day. If the app ever becomes
  commercial, the owner has to contact Merriam-Webster about a commercial licence.
- **Word-field lightning in Both mode** keeps today's behaviour (Translation → Word). Whether a
  definition should ever feed back into Word is not asked for.
