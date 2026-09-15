---
status: living
updated_at: "2026-09-15"
---

# Architecture — flutter_vocabulary_app (simplified)

> One app package, one `lib/`, feature folders. Two libraries carry the structure: **go_router**
> (typed routes) and **Riverpod** (state + dependency injection). Everything else in the app stays
> exactly as it is today — same packages, same widgets, same look. The earlier, larger design
> (workspace packages, Retrofit, Isar, Clean-ish layers) lives on branch
> `chore/architecture-migration` with its ADRs; it is parked, not rejected.

## 1. Folder layout

```
lib/
  main.dart                     runApp(ProviderScope(child: App()))
  app.dart                      MaterialApp.router — theme unchanged
  router/
    routes.dart (+ routes.g.dart)   the ONLY place routes are declared (go_router_builder)
  config/
    vocab_api_config.dart       the Worker URL + secret as constants — kept, gitignored, as today
    azure_config.dart           pre-existing, untouched by this plan
  core/
    providers.dart (+.g)        providers for services: photoScaler, vocabPhotoService, wordStore
    models/                     word_pair.dart, vocab_word.dart — moved, unchanged
    services/                   photo_scaler.dart, vocab_photo_service.dart, word_store.dart (new: persistence)
    widgets/                    synced_text_field_row.dart — moved, unchanged
  features/
    word_input/
      word_input_screen.dart          the screen: composes widgets below, owns controllers/focus as today
      word_input_notifier.dart (+.g)  AsyncNotifier<List<WordPair>> + debounced save() — the main new logic
      lightning_rules.dart            two pure lightning predicates, cut unchanged (see step 4 findings)
      widgets/                        pieces CUT from word_input_screen.dart, code unchanged:
        word_row_item.dart              _buildItem
        translation_dots_button.dart    _buildTranslationDotsButton (popup_menu_2 stays)
        vocab_result_dialog.dart        showVocabResultDialog (was _showVocabResultDialog)
        word_input_speed_dial.dart      the FAB (flutter_speed_dial stays)
    words_table/
      words_table_screen.dart         reads words from the notifier instead of a constructor arg
```

No `packages/`, no workspace, no `feature_*` pub packages. A feature is a folder.

## 2. Rules

1. **Routing** — screens are opened only through the typed route classes in `lib/router/routes.dart`
   (`const WordsTableRoute().go(context)`). No `Navigator.push`, no `MaterialPageRoute`, no string
   paths anywhere else. Route params are IDs/primitives, never objects. Dialogs and bottom sheets
   are not routes — `showDialog` stays as it is.
2. **State + DI** — services are reached via providers in `lib/core/providers.dart`
   (`ref.read(vocabPhotoServiceProvider)`), never via `static instance` or constructed inline in a
   widget. Screen-level data (the word list) lives in a `@riverpod` notifier; transient widget
   state (text controllers, focus nodes, popup controllers, loading spinners, drag mode) stays in
   the widget's `State` exactly as today.
3. **Features don't import each other's screens** — they navigate through routes and share data
   through providers in `core/`.
4. **No UI changes during structural work.** Same packages (`popup_menu_2`, `flutter_speed_dial`,
   `screenshot`, `translator`, `http`, `share_plus`, `image_picker`), same widget trees, same
   animations. Code is cut and pasted into new files, not rewritten. If a file must change to
   compile in its new home, the change is imports and parameters only.
5. **Secrets stay where they are** — `lib/config/vocab_api_config.dart`, a gitignored constant.
   No `--dart-define`, no env files, for now.
6. **No new libraries and no removed libraries** without asking. The additions for this plan are
   exactly: `go_router`, `go_router_builder`, `flutter_riverpod`, `riverpod_annotation`,
   `riverpod_generator`, `build_runner`, `shared_preferences`.
7. **One file ≈ one thing.** The screen file composes; widget files draw; the notifier holds data.
   Aim for files under ~300 lines, but do not split a widget just to hit a number.

## 3. How the pieces talk

```mermaid
flowchart LR
  S[WordInputScreen] -->|ref.watch| N[WordInputNotifier<br/>List&lt;WordPair&gt;]
  S -->|ref.read| P[vocabPhotoServiceProvider<br/>photoScalerProvider]
  N -->|save/load JSON| W[wordStoreProvider<br/>shared_preferences]
  S -->|WordsTableRoute().go| T[WordsTableScreen]
  T -->|ref.watch| N
```

- `WordInputNotifier` owns the list of pairs, add/remove/reorder/update, and a debounced `save()`;
  `build()` loads from `WordStore` (empty list on first launch or corrupt data — never throws).
- The screen keeps its controllers and per-row flags; on every change it calls the notifier
  (`updatePair(index, word, translation)`, `removeAt`, `reorder`, `addAll`). The parallel lists in
  the screen are allowed to remain for now — they are a later, optional cleanup.
- `WordsTableScreen` watches the notifier and no longer receives `List<WordPair>` via constructor.

## 4. Checklist for any change

- [ ] `flutter analyze` clean; `dart run build_runner build --delete-conflicting-outputs` run, `.g.dart` committed
- [ ] `grep -rn "Navigator.push\|MaterialPageRoute" lib` → only `lib/router/` (or nothing)
- [ ] `grep -rn "static final .* instance" lib` → only `lib/core/services/photo_scaler.dart` (`PhotoScaler.instance`, documented exception: the singleton stays for now, wrapped by `photoScalerProvider`)
- [ ] On device, the walkthrough in `docs/refactoring-plan.md` §"Behaviour that must not change" passes
