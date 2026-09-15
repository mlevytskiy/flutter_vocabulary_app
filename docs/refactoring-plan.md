---
status: living
updated_at: "2026-09-15"
---

# Refactoring plan — go_router + Riverpod + feature folders, nothing else

> Five steps. The app runs after each one; each is one commit. **This is a structural move, not a
> redesign** — every screen must look and behave exactly as before. The one functional addition is
> that the word list survives an app restart (step 3), because that was the part of the previous
> attempt worth keeping.
>
> What the previous attempt got wrong, and this plan forbids: rewriting widgets while moving them
> (the popup menu and the FAB changed appearance), deleting the API secret constant in favour of
> env files, and creating a `packages/` tree of five pub packages. None of that happens here.

## Behaviour that must not change (check on device after every step)

1. Open app → one empty row, focus in the Word field.
2. Type an English word → the lightning icon appears per `docs/lightning_icon_rules.md`; tap it →
   translation fills; the **dots popup** (`popup_menu_2`, same look, same position, same options)
   shows alternatives; picking one replaces the translation. (On `master` today those "options"
   are a hardcoded 3-item stub, not real Google Translate results — see
   [`docs/tasks/README.md`'s "Known gap"](./tasks/README.md#known-gap--the-dots-popup-has-no-real-google-translate-results-on-master).
   "Same options" means the stub is unchanged, not that it suddenly shows real translations.)
3. Type a Ukrainian translation first → the Word-side lightning fills the English word.
4. The **FAB** (`flutter_speed_dial`): same open/close animation, same icon sizes, same children,
   same order.
5. Photo: take a photo → analyzing overlay → result dialog with `aiMs` time and removable words →
   confirm → rows added. Background the app during the camera and return → lost-photo recovery still works.
6. Long-press / drag mode reorders rows; delete removes a row; a trailing empty row always exists, exactly one.
7. Table button → table screen with the valid pairs → Share → the share sheet opens with a `.txt`
   whose content is identical to before (header lines `#separator:tab`, `#html:true`, `#tags column:3`).
8. Screenshot share works as before.

If any item differs after a step, the step is not done.

---

## Step 1 — Folder move + Riverpod providers for services *(S)*

**Goal:** the new folder layout exists; services come from providers; nothing else changes.

Do:
1. `pubspec.yaml`: add `flutter_riverpod`, `riverpod_annotation`; dev: `riverpod_generator`,
   `build_runner`. Do **not** remove or replace any existing dependency.
2. Move files (git mv, content unchanged except imports):
   - `lib/models/*` → `lib/core/models/`
   - `lib/services/*` → `lib/core/services/`
   - `lib/widgets/synced_text_field_row.dart` → `lib/core/widgets/`
   - `lib/screens/word_input_screen.dart` → `lib/features/word_input/word_input_screen.dart`
   - `lib/screens/words_table_screen.dart` → `lib/features/words_table/words_table_screen.dart`
   - `lib/config/` stays.
3. `lib/core/providers.dart`:
   ```dart
   @Riverpod(keepAlive: true)
   VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

   @Riverpod(keepAlive: true)
   PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance;   // singleton stays for now; provider is the door
   ```
4. `main.dart`: wrap the app in `ProviderScope`. Keep `unawaited(PhotoScaler.instance.start())`
   exactly where it is — cold-start behaviour is not part of this plan.
5. `WordInputScreen` becomes a `ConsumerStatefulWidget` (`State` → `ConsumerState`); replace the
   field `final VocabPhotoService _vocabPhotoService = VocabPhotoService();` with
   `ref.read(vocabPhotoServiceProvider)` at the call sites. That is the only edit inside the screen.
6. `dart run build_runner build --delete-conflicting-outputs`, commit `providers.g.dart`.

Done when: app runs; the on-device list above passes; `find lib -name "*.dart"` shows the new tree
and no `lib/screens`, `lib/services`, `lib/models`, `lib/widgets`.

Commit: `refactor: step 1 — feature folders, Riverpod providers for services`

---

## Step 2 — go_router with typed routes *(S)*

**Goal:** the two screens are reached through the route table; the table screen no longer takes
the list as a constructor argument.

Do:
1. `pubspec.yaml`: add `go_router`; dev: `go_router_builder`.
2. `lib/router/routes.dart`:
   ```dart
   part 'routes.g.dart';

   @TypedGoRoute<WordInputRoute>(
     path: '/',
     routes: [TypedGoRoute<WordsTableRoute>(path: 'table')],
   )
   class WordInputRoute extends GoRouteData with $WordInputRoute {
     const WordInputRoute();
     @override
     Widget build(BuildContext context, GoRouterState state) => const WordInputScreen();
   }

   class WordsTableRoute extends GoRouteData with $WordsTableRoute {
     const WordsTableRoute();
     @override
     Widget build(BuildContext context, GoRouterState state) => const WordsTableScreen();
   }

   final appRouter = GoRouter(routes: $appRoutes);
   ```
   (Use whatever mixin name `go_router_builder` generates — follow `routes.g.dart`.) Default
   `MaterialPage` transitions, so the push animation is the same as `MaterialPageRoute` today.
3. `lib/app.dart`: `MaterialApp.router(routerConfig: appRouter, theme: <unchanged>, title: <unchanged>, debugShowCheckedModeBanner: false)`.
   `main.dart` calls `runApp(const ProviderScope(child: App()))`.
4. The table needs the words without a constructor arg. For this step only, add a tiny provider
   `final validPairsProvider = StateProvider<List<WordPair>>((_) => []);` in `core/providers.dart`;
   `_navigateToTableScreen` sets it and calls `const WordsTableRoute().go(context)`;
   `WordsTableScreen` reads it. Step 3 replaces this with the real notifier.
   Remove `Navigator.push` + `MaterialPageRoute` from `word_input_screen.dart`. The `Navigator.pop`
   calls inside dialogs stay — dialogs are not routes.
5. Build, commit `routes.g.dart`.

Done when: `grep -rn "Navigator.push\|MaterialPageRoute" lib` is empty; back button from the table
returns to the input screen with all rows intact; on-device list passes.

Commit: `refactor: step 2 — go_router typed routes, table screen reads words from a provider`

---

## Step 3 — The word list in a notifier, persisted *(M)*

**Goal:** `List<WordPair>` is owned by a Riverpod notifier and survives an app restart. The
screen keeps everything else it has today.

Do:
1. `pubspec.yaml`: add `shared_preferences`. (`WordPair` gets hand-written `toJson`/`fromJson` —
   no codegen, no new model.)
2. `lib/core/services/word_store.dart`: `Future<List<WordPair>> load()` and
   `Future<void> save(List<WordPair>)` over one JSON-encoded key. `load()` returns `[]` on first
   launch or corrupt data — never throws. Provider `wordStoreProvider` in `core/providers.dart`.
3. `lib/features/word_input/word_input_notifier.dart`:
   ```dart
   @Riverpod(keepAlive: true)
   class WordInputNotifier extends _$WordInputNotifier {
     Timer? _saveTimer;

     @override
     Future<List<WordPair>> build() async {
       ref.onDispose(() => _saveTimer?.cancel());
       return ref.read(wordStoreProvider).load();
     }

     List<WordPair> get _pairs => state.value ?? const [];

     void setPairs(List<WordPair> pairs)     { state = AsyncData(List.of(pairs)); _scheduleSave(); }
     void updateAt(int i, {String? word, String? translation}) { … _scheduleSave(); }
     void removeAt(int i)                     { … }
     void reorder(int oldIndex, int newIndex) { … }
     void addAll(List<WordPair> pairs)        { … }
     Future<void> flush() async { _saveTimer?.cancel(); await ref.read(wordStoreProvider).save(_pairs.where((p) => !p.isEmpty).toList()); }

     void _scheduleSave() { _saveTimer?.cancel(); _saveTimer = Timer(const Duration(milliseconds: 500), flush); }
   }
   ```
   Blank pairs are never saved (the trailing empty row is re-created by `_checkAndAddNewPair`
   after load, so there is never a second one).
4. In `WordInputScreen`, `_wordPairs` becomes a **mirror** of the notifier, not a second source
   of truth: the screen keeps its `List<WordPair> _wordPairs` field (so `_addControllersForIndex`,
   `_ensureRowStateSynced`, `_buildItem` and every index-based method keep working unchanged), but
   - on first data from `ref.watch(wordInputNotifierProvider)`: replace `_wordPairs`' contents,
     call `_addControllersForIndex` for every row, then `_checkAndAddNewPair()`, then focus the
     trailing row (this is the restore path);
   - wherever the screen mutates `_wordPairs` today (controller listeners in
     `_addControllersForIndex`, `_checkAndAddNewPair`, `_selectTranslationOption`,
     `_addWordsFromPhoto`, `_removeItem`, `_reorderItems`), add the matching notifier call after
     the existing code. Do not restructure those methods.
   - `didChangeAppLifecycleState(paused)`: call `ref.read(wordInputNotifierProvider.notifier).flush()`
     (the OS kills the app while the camera is open — this is the last guaranteed callback).
5. `WordsTableScreen` watches `wordInputNotifierProvider` and filters `isValid`; delete
   `validPairsProvider` from step 2.
6. Test: `test/word_store_test.dart` with `SharedPreferences.setMockInitialValues({})` — round trip
   of 3 pairs (one with a tab, one with a newline), empty store → `[]`, corrupt store → `[]`.

Done when: enter 5 pairs → force-quit from the app switcher → reopen → 5 rows + one blank, focus
in the blank row; repeat 3× with no growth; photo-added words survive too; the test passes.

Commit: `feat: step 3 — word list in a Riverpod notifier, persisted with shared_preferences`

---

## Step 4 — Split the screen file by cut-and-paste *(S)*

**Goal:** `word_input_screen.dart` (1,318 lines) becomes a screen plus four widget files, with the
**same widget trees**. This is a move, not a rewrite.

Do, one extraction at a time, building after each:
1. `widgets/vocab_result_dialog.dart` ← `_showVocabResultDialog` + `_formatDuration`. Becomes a
   top-level `Future<List<VocabWord>?> showVocabResultDialog(BuildContext, VocabAnalysisResult)`
   with the identical dialog body.
2. `widgets/translation_dots_button.dart` ← `_buildTranslationDotsButton`. A `StatelessWidget`
   taking the same values the method reads (`index`, the `CustomPopupMenuController`, the options,
   the callbacks). **`popup_menu_2` stays**; the popup's content, size, arrow and position are
   copied verbatim.
3. `widgets/word_input_speed_dial.dart` ← the `SpeedDial(...)` subtree from `build`. **`flutter_speed_dial`
   stays** with the same `animatedIcon`/`children`/sizes/curves as today; the widget takes callbacks.
4. `widgets/word_row_item.dart` ← `_buildItem`. Takes the controllers, focus nodes, flags and
   callbacks for one row as parameters; the screen still owns the parallel lists and passes
   `index`-th entries. (Yes, the parallel lists remain — that is deliberate.)
5. Lightning predicates (`_isTranslationFilled`, `_isRealTranslation`, `_isEnglishLetter`) may move
   to `lightning_rules.dart` as pure functions **only if** their bodies are pasted unchanged.

Rules: no widget is replaced by a different widget; no package swapped; no `const` cleanups, no
"while I'm here" fixes. Prefer passing a few more parameters over inventing a new state object.

Done when: the screen file is under ~500 lines, the four widget files exist, `flutter analyze`
clean, and the on-device list passes — with special attention to items 2 and 4 (popup and FAB).

Commit: `refactor: step 4 — split word_input_screen into widget files (no UI change)`

---

## Step 5 — Close out *(S)*

1. `docs/architecture.md` §1 tree matches `find lib -name "*.dart"`.
2. `CLAUDE.md` checks pass (`build_runner`, `analyze`, the grep).
3. Remove anything temporary left from steps 2–3.
4. Write a short `## What changed` at the bottom of this file: files moved, providers added, routes
   added — so the next agent session starts from facts.

Commit: `docs: step 5 — plan closed, structure documented`

---

## Deferred (decide later, not now)

- Replacing the ten parallel lists in `WordInputScreen` with a per-row state class.
- Isar / a real DB instead of `shared_preferences` (only when querying is needed — the review screen).
- Dio + Retrofit instead of `http` (only when a second API appears).
- Extracting packages / a pub workspace (only if a second app target appears).
- `--dart-define` secrets (only before the repo becomes public).
- Integration tests (a baseline one is worth adding right after step 5 if the plan went smoothly).

The full version of each of these is on branch `chore/architecture-migration` (`docs/architecture/`,
`docs/adr/`). The product docs (`docs/idea-brief.md`, `docs/roadmap.md`, `docs/tasks/`) are back on
`master`; this plan is `docs/tasks/task-00-restructure.md` in the task index.

---

## What changed

Executed 2026-09-15, steps 1-5, across three commits (`9a0deb4` steps 1-2, `5e18846` step 3,
`9da9291` step 4) plus this doc pass for step 5. `find lib -name "*.dart"` matches
`docs/architecture.md` §1 exactly.

**Files moved** (git mv, content unchanged except import paths):
- `lib/models/*` -> `lib/core/models/`
- `lib/services/*` -> `lib/core/services/`
- `lib/widgets/synced_text_field_row.dart` -> `lib/core/widgets/`
- `lib/screens/word_input_screen.dart` -> `lib/features/word_input/word_input_screen.dart`
- `lib/screens/words_table_screen.dart` -> `lib/features/words_table/words_table_screen.dart`

**Files added:**
- `lib/core/providers.dart` (+`.g.dart`) — `vocabPhotoServiceProvider`, `photoScalerProvider`,
  `wordStoreProvider`
- `lib/router/routes.dart` (+`.g.dart`) — `WordInputRoute` (`/`), `WordsTableRoute` (`/table`),
  `appRouter`
- `lib/app.dart` — `MaterialApp.router`, pulled out of `main.dart`
- `lib/core/services/word_store.dart` — `WordStore.load()`/`save()` over one
  `shared_preferences` JSON key; `load()` never throws
- `lib/features/word_input/word_input_notifier.dart` (+`.g.dart`) — `WordInputNotifier`
  (`AsyncNotifier<List<WordPair>>`): `setPairs`/`updateAt`/`removeAt`/`reorder`/`addAll`, a
  500ms-debounced `flush()`
- `lib/features/word_input/widgets/{word_row_item,translation_dots_button,vocab_result_dialog,
  word_input_speed_dial}.dart` — step 4's cut-and-paste extractions
- `lib/features/word_input/lightning_rules.dart` — the two pure lightning predicates
  (`isRealTranslation`, `isEnglishLetter`); `_isTranslationFilled` stayed in the screen (not pure)
- `test/word_store_test.dart` — 4 tests, all passing

**Providers added:** `vocabPhotoServiceProvider`, `photoScalerProvider`, `wordStoreProvider`,
`wordInputNotifierProvider`. `validPairsProvider` (step 2's temporary bridge) was added then
deleted in step 3, as planned.

**Routes added:** `WordInputRoute` (`/`), `WordsTableRoute` (`/table`).

**Deviations from the plan, and why:**
- `PhotoScaler.instance` singleton remains (`lib/core/services/photo_scaler.dart`), wrapped by
  `photoScalerProvider` — this is the grep exception CLAUDE.md and `docs/architecture.md` §4 both
  name explicitly, not an oversight.
- `showVocabResultDialog` (step 4, `vocab_result_dialog.dart`) keeps the original 4-parameter
  signature (`words`, `compressDuration`, `requestDuration`, `aiDuration`) rather than the plan's
  assumed single `VocabAnalysisResult` parameter — `master`'s `_processPickedPhoto` computes the
  two durations from separate stopwatches around the compress and request steps, so a single
  result object doesn't carry what the dialog needs. Dialog body is identical either way.
- `word_input_screen.dart` is 949 lines after all five step-4 extractions, not the "~500 lines"
  in Done-when. The gap is real scope the plan doesn't name as an extraction target: the
  photo-capture pipeline (`_takePhotoForVocabulary`, `_processPickedPhoto`, `_pollForLostPhoto`,
  `_recoverLostPhoto`), the step-3 persistence wiring (`_restoreFromStore`, the notifier calls
  threaded through every mutation site), and the step-1/2 Riverpod/go_router plumbing all live in
  this file and weren't part of the plan's original 1,282-line inventory. No further extraction
  was invented beyond the plan's explicit list, per its own "do not improvise a different
  structure" rule — a future session could split the photo-capture pipeline into its own
  controller/notifier if this file's size becomes a problem, but that's new scope, not this plan's.
- The dots popup (`TranslationDotsButton`) still renders three hardcoded placeholder strings, not
  real Google Translate results — pre-existing on `master`, unrelated to this restructure. See
  `docs/tasks/task-01-remove-reverso.md`'s note and `docs/tasks/README.md`'s "Known gap" section.
- No `test/` directory existed on `master` before step 3; the README's claim of one pre-existing
  live-network smoke test refers to the parked `chore/architecture-migration` branch, not this
  one. `test/word_store_test.dart` (step 3) is the first test on this branch.

**Verified on device after every step:** the full 8-item "Behaviour that must not change" list
above, plus step 3's restart-persistence checklist (5 pairs -> force-quit -> reopen -> 5 rows +
blank with focus, repeated 3x with no growth; photo-added words survive too). Special attention
was paid to items 2 (dots popup) and 4 (FAB) in steps 1, 2, and 4, per this plan's own warning
about where the previous attempt regressed — both held pixel-for-pixel throughout.

**Left for a later, separate task (not this plan):** wiring real Google Translate results into
the dots popup (needs porting `translation_repository`/`translate_api` from
`chore/architecture-migration`, or a fresh implementation); the deferred items already listed
above.

