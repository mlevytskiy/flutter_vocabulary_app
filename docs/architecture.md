---
status: living
updated_at: "2026-10-06"
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
    providers.dart (+.g)        providers for services: photoScaler, imagePicker (camera/gallery
                                picks, photo-from-gallery), vocabPhotoService, sessionStore,
                                googleTranslateService, pronunciationService, sessionPublishService,
                                sessionById, dictionaryService (definition-mode),
                                sourcePhotoStore, photoUploadService (keepAlive, so uploads outlive
                                the words table; good-looking-web); plus the
                                dragMode display preference (task-13) and the persisted
                                wordDetailMode preference (definition-mode)
    models/                     vocab_word.dart — moved, unchanged
                                word_pair.dart (+.g) — Isar @embedded row: the two strings plus the
                                dots/lightning extras that make a restored row look untouched;
                                sourceId links a recognised row to its photo (good-looking-web)
                                session.dart (+.g) — Isar @collection: a set of words with an
                                identity and timestamps (task-03); its sources (photos taken, in
                                order) and the publishedId + editToken a republish overwrites
                                (good-looking-web, ADR-0008)
                                session_source.dart (+.g) — Isar @embedded SessionSource: where words came from.
                                SourceKind { photo, set } (photo first, so older records read as
                                photos); id (the declared source id), fileName, takenAt, and for a
                                set its name + plain url. Stored name stays SourcePhoto
                                (good-looking-web; import-from-quizlet, ADR-0005)
                                translation_result.dart (Google's dictionary block)
                                definition_result.dart (the Worker's dictionary answer:
                                senses / not found / unavailable; definition-mode)
    services/                   photo_scaler.dart, vocab_photo_service.dart,
                                session_store.dart (persistence: Isar + the current-session pointer,
                                and beside it the History pick record — session id + time,
                                edit-session-from-history ADR-0002)
                                google_translate_service.dart + translate_response_parser.dart
                                (translate_a/single with dt=t,bd,at + the part-of-speech rule)
                                pronunciation_service.dart (task-04)
                                session_publish_service.dart (task-05: POST /sessions → public link;
                                sends the word detail mode + definitions, definition-mode; with
                                every set and, with "Include photos" on, every photo that has a
                                linked row (no cap; each with its kind, a set with name +
                                url) and each row's sourceId; republishes with the stored token,
                                good-looking-web)
                                dictionary_service.dart (definition-mode: POST /define on the Worker)
                                source_photo_store.dart (the kept 1600 px photo files under
                                source_photos/ in the documents dir; never throws, good-looking-web)
                                photo_upload_service.dart (background POST /sessions/<id>/sources/
                                <sourceId> after a publish, retried with growing pauses; the link
                                dialog never waits for it, good-looking-web)
                                quizlet_link.dart (import-from-quizlet: pure rules — find a set link
                                in pasted text, the plain https://quizlet.com/<id>/<name>/ form the
                                Worker accepts, which web view navigations may be followed)
                                quizlet_page_script.dart (the thin JavaScript the web view runs on
                                a set page; returns raw JSON, no interpretation)
                                quizlet_set_parser.dart (parseQuizletPage: raw JSON → set found /
                                robot check / nothing yet; never throws)
                                quizlet_cards.dart (cards → proposed words: a Ukrainian back is
                                the translation, any other the definition; cleaning, the 500
                                character cut, duplicates, skipped cards, the numbers the results
                                dialog names)
    widgets/                    synced_text_field_row.dart — moved, unchanged
  features/
    word_input/
      word_input_screen.dart          the screen: composes widgets below, owns controllers/focus as today
      quizlet_read_controller.dart    waits for and decides a read: 30 s limit per phase, clock paused
                                      during a robot check; outcomes succeeded / failed / cancelled
      quizlet_import_flow.dart        runQuizletImport: link dialog → progress dialog (reads, shows
                                      the cards, Cancel still works; no machine translation) → results
                                      dialog → addWords on Done; a result for another session is dropped
      word_input_notifier.dart (+.g)  AsyncNotifier<Session> + the launch rule + debounced save()
                                      + switchTo(id): makes a History session current without
                                      stamping it (edit-session-from-history)
      lightning_rules.dart            two pure lightning predicates, cut unchanged (see step 4 findings)
      widgets/                        pieces CUT from word_input_screen.dart, code unchanged:
        word_row_item.dart              _buildItem
        translation_dots_button.dart    _buildTranslationDotsButton (popup_menu_2 stays)
        vocab_result_dialog.dart        showVocabResultDialog (was _showVocabResultDialog) and
                                        showQuizletResultDialog (set name, "Read X of Y", skipped
                                        cards, "No new words in this set.")
        quizlet_link_dialog.dart        showQuizletLinkDialog: how-to animation, paste text, refuses
                                        text without a set link
        quizlet_link_how_to.dart        the link dialog's animation (open set, Share, Copy link, paste)
        quizlet_logo_icon.dart          the + menu's painted white Quizlet-like "Q"
        photo_source_dialog.dart        showPhotoSourceDialog: Camera / Photos as two side-by-side cards
        quizlet_progress_dialog.dart    showQuizletProgressDialog: a pager of skeleton cards, then the
                                        set's cards (scrolled first to last), over a hidden web view
                                        of the set page (webview_flutter); the page is shown full
                                        size only while Quizlet's robot check is on screen
        translation_options_content.dart  the dots popup's body: dictionary chips by part of speech
        word_input_speed_dial.dart      the FAB (flutter_speed_dial stays); "From subtitles" dark grey
                                        with the captions icon; it shares the Scaffold's floating-button
                                        slot with the Settings button, so both rise above a SnackBar
    words_table/
      words_table_screen.dart         reads words from the notifier (no sessionId) or from
                                      sessionByIdProvider (a History row), read-only either way;
                                      Share → bottom sheet: file (TSV) or link (publish, task-05);
                                      the "Include photos (N)" switch (photos only; Quizlet sets
                                      are always sent) with stacked thumbnails sits above the
                                      table; the sheet warns about public photos and that
                                      a republish replaces the partner's edits (good-looking-web);
                                      a History session that is not current gets a red Edit FAB →
                                      "Do you want to edit…?" → switchTo + WordInputRoute().go
                                      (edit-session-from-history)
    history/
      history_screen.dart             all non-empty sessions, newest lastLocalModifiedAt first;
                                      a row opens WordsTableScreen for that sessionId
    settings/
      settings_screen.dart            the drag-and-drop mode switch (task-13) and the word
                                      detail mode — translation / definition / both
                                      (definition-mode); writes dragModeProvider and
                                      wordDetailModeProvider, which the input screen reads
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
   `translator`, `http`, `share_plus`, `image_picker`), same widget trees, same
   animations. Code is cut and pasted into new files, not rewritten. If a file must change to
   compile in its new home, the change is imports and parameters only.
5. **Secrets stay where they are** — `lib/config/vocab_api_config.dart`, a gitignored constant.
   No `--dart-define`, no env files, for now.
6. **No new libraries and no removed libraries** without asking. The additions for this plan are
   exactly: `go_router`, `go_router_builder`, `flutter_riverpod`, `riverpod_annotation`,
   `riverpod_generator`, `build_runner`, `shared_preferences`, `path_provider`,
   `isar_community`, `isar_community_flutter_libs`, `isar_community_generator` (task-03, D8),
   `flutter_tts` (task-04), and `image_picker_android` + `image_picker_platform_interface`
   (photo-from-gallery, [ADR-0001](features/photo-from-gallery/adr/0001-turn-on-the-android-photo-picker-for-gallery-picks.md):
   already transitive through `image_picker`, made direct only so `main.dart` can set
   `useAndroidPhotoPicker = true`), and `webview_flutter` (import-from-quizlet,
   [ADR-0002](features/import-from-quizlet/adr/0002-show-the-set-page-with-webview-flutter.md):
   the Quizlet set page in the progress dialog; JavaScript on, no JavaScript channel, top-level
   navigation only to the pasted set's Quizlet pages; no new permission).

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
  S -->|HistoryRoute().go| H[HistoryScreen]
  H -->|watchNonEmpty| W
  H -->|WordsTableRoute sessionId| T
  T -->|sessionByIdProvider| W
  S -->|SettingsRoute push| G[SettingsScreen]
  G -->|toggle| D[dragModeProvider]
  D -->|watch| S
  G -->|set| M[wordDetailModeProvider<br/>persisted preference]
  M -->|watch| S
  M -->|watch| T
  S -->|define| X[dictionaryServiceProvider<br/>Worker /define]
  S -->|keep photo| K[sourcePhotoStoreProvider<br/>source_photos/ files]
  T -->|publish| U[sessionPublishServiceProvider<br/>Worker POST /sessions]
  T -->|enqueue declared photos| V[photoUploadServiceProvider<br/>Worker POST /sessions/id/sources]
  V -->|read bytes| K
```

- The shared page itself (editing, photos, autofill) is served by the Worker, not the app: see
  `vocab-photo-api/README.md` and `docs/features/good-looking-web/sad.md`.

- `WordInputNotifier` owns the current `Session` — add/remove/reorder/update plus a debounced
  save. Its `build()` runs the **launch rule**: reuse the current session if this device touched
  it under 5 minutes ago — counting a pick from History as a touch (or if it never got a word), otherwise start a fresh one and hand the
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

### Import from Quizlet (import-from-quizlet)

The red + menu's "Import from Quizlet" (it took the old Screenshot item's place; the `screenshot`
package is gone) runs `runQuizletImport` in `quizlet_import_flow.dart`:

1. `showQuizletLinkDialog` finds a set link in the pasted text and reduces it to the plain
   `https://quizlet.com/<id>/<name>/` (`quizlet_link.dart`).
2. `showQuizletProgressDialog` opens that page in a `webview_flutter` view (JavaScript on, no
   JavaScript channel, top-level navigation only to that set's Quizlet pages). On every tick
   `QuizletReadController` runs `quizlet_page_script.dart` and hands the raw JSON to
   `parseQuizletPage`; the first read with cards of the pasted set ends the wait. No cards within
   30 s (the clock stops while a robot check is on screen) is one failure message; Cancel/Back is
   silent.
3. Still inside the progress dialog, `quizlet_cards.dart` turns the cards into proposed words (term
   as the word; a back whose letters are at least half Cyrillic as the translation, any other back
   as the definition; the example in the definition; at most 500 characters per field; duplicates
   and words already in the session left out). Nothing is machine-translated: a field the card does
   not fill stays empty, so its lightning looks like a typed word's.
4. `showQuizletResultDialog` shows the set name and the cards. Done with at least one kept word
   adds them to the session via `addWords`, linked to a new `SessionSource(kind: set, name, url)`;
   a result for a session other than the current one at Start is dropped.

Sources and publishing: a session's `sources` hold photos and sets in one list. The old cap of 10
photos is gone; publishing declares every source that has a linked row, bounded only by the Worker's
500 entries and 256 KB. Sets with a linked row are always published; the "Include photos (N)"
switch publishes or hides the photos only; only photos are uploaded afterwards (`photo_upload_service.dart` skips sets, which have no
bytes). The Worker side is in `vocab-photo-api/README.md`; the design is in
`docs/features/import-from-quizlet/sad.md`.

## 4. Checklist for any change

- [ ] `flutter analyze` clean; `dart run build_runner build --delete-conflicting-outputs` run, `.g.dart` committed
- [ ] Tests per [`testing.md`](testing.md): new behaviour has tests; `tool/test.sh changed` passes
      (smoke + the tests this branch touches). The full regression runs only when the owner asks.
- [ ] `grep -rn "Navigator.push\|MaterialPageRoute" lib` → only `lib/router/` (or nothing)
- [ ] `grep -rn "static final .* instance" lib` → only `lib/core/services/photo_scaler.dart` (`PhotoScaler.instance`, documented exception: the singleton stays for now, wrapped by `photoScalerProvider`)
- [ ] On device, the walkthrough in `docs/refactoring-plan.md` §"Behaviour that must not change" passes
