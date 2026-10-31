---
status: living
updated_at: "2026-10-18"
---

# Architecture — flutter_vocabulary_app (simplified)

> One app package, one `lib/`, feature folders. Two libraries carry the structure: **go_router**
> (typed routes) and **Riverpod** (state + dependency injection). Everything else in the app stays
> exactly as it is today — same packages, same widgets, same look. The earlier, larger design
> (workspace packages, Retrofit, Isar, Clean-ish layers) lives on branch
> `chore/architecture-migration` with its ADRs; it is parked, not rejected.

## 1. Folder layout

No `packages/`, no workspace, no `feature_*` pub packages. A feature is a folder.
The full tree of `lib/` is in [`folder-layout.md`](folder-layout.md); update it when you add or move files.

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

   **Pins after the toolchain upgrade (owner, 2026-10-24; Flutter 3.47.8 / Dart 3.13).** The
   generators now all sit on `build ^4` / `source_gen ^4`: `riverpod_generator` 4.x,
   `go_router_builder` 4.x and `isar_community_generator` 3.4.1, with `build_runner` 2.16. The
   Isar packages (`isar_community`, `isar_community_flutter_libs`, `isar_community_generator`)
   are pinned to `3.4.1` exactly (no caret) so a `pub upgrade` cannot move the database format or
   the generator. (Before, they were held at `3.3.0-dev.1`, the last release on `build 2.x`,
   because `riverpod_generator` 2.x and `go_router_builder` 3.x were on `build 2`.)
   `go_router` stays on 17.x (`^17.5.0`): go_router 18 moved to the `material_ui` package and
   only recognises *that* package's `MaterialApp`; with `package:flutter/material.dart`'s
   `MaterialApp` it falls back to `NoTransitionPage` and a plain `HeroController`, so every push
   and pop would lose its slide (and the iOS back swipe) and heroes their Material arc.
   Riverpod 3 notes: `retry` is off on the root `ProviderScope` (`noProviderRetry` in
   `providers.dart`), so a failed provider shows its error at once as before; every
   AsyncNotifier keeps Riverpod 2's notify rule (`asyncNotifyAsBefore`), since Riverpod 3
   compares states with `==` and the words notifier stores the same, changed, collection again;
   generated names drop a class's `Notifier` suffix (`WordsNotifier` → `wordsProvider`).
   Note the import is `package:isar_community/isar.dart` (the package kept Isar's library name).
7. **One file ≈ one thing.** The screen file composes; widget files draw; the notifier holds data.
   Aim for files under ~300 lines, but do not split a widget just to hit a number.

## 3. How the pieces talk

```mermaid
flowchart LR
  S[WordsScreen] -->|ref.watch| N[WordsNotifier<br/>WordCollection]
  S -->|ref.read| P[vocabPhotoServiceProvider<br/>photoScalerProvider]
  N -->|put/byId/newest| W[sessionStoreProvider<br/>CollectionStore: Isar 'vocab'<br/>+ current_session_id pointer]
  S -->|WordsTableRoute().go| T[WordsTableScreen]
  T -->|ref.watch| N
  T -->|LearnRoute push| L[LearnScreen]
  L -->|Start: ComingSoonRoute push| C[ComingSoonScreen]
  L -->|Start with a group: ExerciseRoute push| EX[exerciseScreen<br/>kit: ExerciseScaffold]
  EX -->|fetchData / check| LA[learnApiServiceProvider<br/>Worker /learn/data, /learn/check]
  EX -->|record| ER[examResultSinkProvider<br/>WordCollection.results]
  L -->|Start with Mnemonic story: StoryRoute push| Y[StoryScreen]
  L -->|ensureGrouped| GN[wordGroupsProvider<br/>core/story]
  GN -->|POST /story/grouping| SA[storyApiServiceProvider<br/>Worker /story/*]
  Y -->|follow / startFor| R[storyRunTrackerProvider<br/>core/story]
  R -->|start, poll, picture| SA
  R -->|put runs| SR[storyRunStoreProvider<br/>Isar StoryRun + mnemonic_pictures/]
  Y -->|watch| SR
  T -->|WordsSettingsRoute push| WS[WordsSettingsScreen]
  WS -->|StoryRunsRoute / StoryRunRoute push| SR2[Story runs screens]
  SR2 -->|watch| SR
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

- `WordsNotifier` owns the current `WordCollection` — add/remove/reorder/update plus a
  debounced save. Its `build()` runs the **launch rule** (collections-screen ADR-0007): after any
  pause it reopens the collection the current-collection pointer names; a missing or binned
  pointer falls back to the newest collection outside the recycle bin, and only an empty store
  creates a first collection. The app never starts a collection by itself and there is no
  RESTORE offer; a new one comes only from "New collection". `sweepBin` runs on open and on
  resume. `CollectionStore` never throws: a bad read answers `null`/`[]`.
- **Who may write a collection** (collections-screen ADR-0003, ADR-0006). Filing — `name`,
  `folderId`, `order`, `binnedAt`, `binnedFromFolderId`, `keep` — is written only by the
  store's own one-transaction actions (rename, createFolder, move, reorder, bin, restore, erase,
  emptyBin, sweepBin). `put(collection)` is for the main screen's autosave only: it copies the
  stored filing over the copy, never lowers `keep`, and writes nothing when the record is gone
  (it never inserts; `create()` does). Every other writer — story runs, word groups, dialogue
  push, exam results, and a late translation, photo reading, Quizlet or subtitle result — uses
  `update(collectionId, change)`, which reads, changes and writes one record in one transaction
  and drops the write (logged) when the collection was erased. **A new background writer must use
  `update`, never a whole-copy `put`.**
- The screen keeps its controllers and per-row flags; on every change it calls the notifier
  (`updatePair(index, word, translation)`, `removeAt`, `reorder`, `addAll`). The parallel lists in
  the screen are allowed to remain for now — they are a later, optional cleanup.
- `WordsTableScreen` watches the notifier and no longer receives `List<WordPair>` via constructor.
- `GoogleTranslateService` is the single translation entry point (`translate` for a plain
  translation, `translateWord` for the part-of-speech rule). One request carries the dictionary
  block too, and the screen keeps it per row in `_translationOptions` so the dots popup reuses it
  without a second call — see `docs/lightning_icon_rules.md`. Retrofit/Dio were the parked
  design's answer here; `docs/retrofit-translation-prompt.md` is the prompt to redo it that way.

### Feature data flows

The Quizlet import, mnemonic story, film dialogues and mixed talk missions are described in
[`architecture-features.md`](architecture-features.md). Read the section for the feature you touch.

## 4. Checklist for any change

- [ ] `flutter analyze` clean; `dart run build_runner build --delete-conflicting-outputs` run, `.g.dart` committed
- [ ] Tests per [`testing.md`](testing.md): new behaviour has tests; `tool/test.sh changed` passes
      (smoke + the tests this branch touches). The full regression runs only when the owner asks.
- [ ] `grep -rn "Navigator.push\|MaterialPageRoute" lib` → only `lib/router/` (or nothing)
- [ ] `grep -rn "static final .* instance" lib` → only `lib/core/services/photo_scaler.dart` (`PhotoScaler.instance`, documented exception: the singleton stays for now, wrapped by `photoScalerProvider`)
- [ ] On device, the walkthrough in `docs/refactoring-plan.md` §"Behaviour that must not change" passes
