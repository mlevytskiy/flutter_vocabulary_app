---
status: living
updated_at: "2026-09-20"
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
    providers.dart (+.g)        providers for services: photoScaler, vocabPhotoService, sessionStore,
                                googleTranslateService, pronunciationService, sessionPublishService,
                                sessionById
    models/                     vocab_word.dart — moved, unchanged
                                word_pair.dart (+.g) — Isar @embedded row: the two strings plus the
                                dots/lightning extras that make a restored row look untouched
                                session.dart (+.g) — Isar @collection: a set of words with an
                                identity and timestamps (task-03)
                                translation_result.dart (Google's dictionary block)
    services/                   photo_scaler.dart, vocab_photo_service.dart,
                                session_store.dart (persistence: Isar + the current-session pointer)
                                google_translate_service.dart + translate_response_parser.dart
                                (translate_a/single with dt=t,bd,at + the part-of-speech rule)
                                pronunciation_service.dart (task-04)
                                session_publish_service.dart (task-05: POST /sessions → public link)
    widgets/                    synced_text_field_row.dart — moved, unchanged
  features/
    word_input/
      word_input_screen.dart          the screen: composes widgets below, owns controllers/focus as today
      word_input_notifier.dart (+.g)  AsyncNotifier<Session> + the launch rule + debounced save()
      lightning_rules.dart            two pure lightning predicates, cut unchanged (see step 4 findings)
      widgets/                        pieces CUT from word_input_screen.dart, code unchanged:
        word_row_item.dart              _buildItem
        translation_dots_button.dart    _buildTranslationDotsButton (popup_menu_2 stays)
        vocab_result_dialog.dart        showVocabResultDialog (was _showVocabResultDialog)
        translation_options_content.dart  the dots popup's body: dictionary chips by part of speech
        word_input_speed_dial.dart      the FAB (flutter_speed_dial stays)
    words_table/
      words_table_screen.dart         reads words from the notifier instead of a constructor arg;
                                      Share → bottom sheet: file (TSV) or link (publish, task-05)
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
   `riverpod_generator`, `build_runner`, `shared_preferences`, `path_provider`,
   `isar_community`, `isar_community_flutter_libs`, `isar_community_generator` (task-03, D8),
   `flutter_tts` (task-04).

   **Why the Isar packages are pinned to `3.3.0-dev.1`, exactly.** Every isar_community release
   from `3.3.0-dev.2` up is built against `build ^3/^4` and `source_gen ^4`, while this project's
   other generators — `riverpod_generator ^2.6.1` and `go_router_builder ^3.0.0` — are built
   against `build ^2` / `source_gen ^2`. Asking for both makes `pub get` fail outright:

   > Because isar_community_generator >=3.3.1 depends on build ^4.0.0 and riverpod_generator
   > <3.0.0-dev.17 depends on build ^2.0.0, version solving failed.

   `3.3.0-dev.1` is the last release still on `build 2.x`, so it is the one version of Isar that
   coexists with the generators already here. Pinned exactly (no caret) so a `pub upgrade` cannot
   drift onto `3.3.0-dev.2` and break the build. The other way out is upgrading riverpod to 3.x,
   which is a breaking API change across every provider — not something task-03 should carry.
   Note the import is `package:isar_community/isar.dart` (the package kept Isar's library name).
7. **One file ≈ one thing.** The screen file composes; widget files draw; the notifier holds data.
   Aim for files under ~300 lines, but do not split a widget just to hit a number.

## 3. How the pieces talk

```mermaid
flowchart LR
  S[WordInputScreen] -->|ref.watch| N[WordInputNotifier<br/>Session]
  S -->|ref.read| P[vocabPhotoServiceProvider<br/>photoScalerProvider]
  N -->|put/byId/newest| W[sessionStoreProvider<br/>SessionStore: Isar 'vocab'<br/>+ current_session_id pointer]
  S -->|WordsTableRoute().go| T[WordsTableScreen]
  T -->|ref.watch| N
```

- `WordInputNotifier` owns the current `Session` — add/remove/reorder/update plus a debounced
  save. Its `build()` runs the **launch rule**: reuse the current session if this device touched
  it under 5 minutes ago (or if it never got a word), otherwise start a fresh one and hand the
  screen a `restorableSessionId` so it can offer the previous session back through a 7-second
  RESTORE snackbar. `SessionStore` never throws: a bad read answers `null`/`[]`.
- The screen keeps its controllers and per-row flags; on every change it calls the notifier
  (`updatePair(index, word, translation)`, `removeAt`, `reorder`, `addAll`). The parallel lists in
  the screen are allowed to remain for now — they are a later, optional cleanup.
- `WordsTableScreen` watches the notifier and no longer receives `List<WordPair>` via constructor.
- `GoogleTranslateService` is the single translation entry point (`translate` for a plain
  translation, `translateWord` for the part-of-speech rule). One request carries the dictionary
  block too, and the screen keeps it per row in `_translationOptions` so the dots popup reuses it
  without a second call — see `docs/lightning_icon_rules.md`. Retrofit/Dio were the parked
  design's answer here; `docs/retrofit-translation-prompt.md` is the prompt to redo it that way.

## 4. Checklist for any change

- [ ] `flutter analyze` clean; `dart run build_runner build --delete-conflicting-outputs` run, `.g.dart` committed
- [ ] `grep -rn "Navigator.push\|MaterialPageRoute" lib` → only `lib/router/` (or nothing)
- [ ] `grep -rn "static final .* instance" lib` → only `lib/core/services/photo_scaler.dart` (`PhotoScaler.instance`, documented exception: the singleton stays for now, wrapped by `photoScalerProvider`)
- [ ] On device, the walkthrough in `docs/refactoring-plan.md` §"Behaviour that must not change" passes
