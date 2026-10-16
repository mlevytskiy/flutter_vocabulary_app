# flutter_vocabulary_app — instructions for agents

Read `docs/architecture.md` first (short). Tests: `docs/testing.md`. If you are doing the
restructuring, follow `docs/refactoring-plan.md` one step at a time. Behaviour spec for the lightning icons:
`docs/lightning_icon_rules.md`. Server: `vocab-photo-api/` (Cloudflare Worker).

## Rules

1. Navigate only via typed routes in `lib/router/routes.dart`. No `Navigator.push`, no string paths.
2. Services come from providers in `lib/core/providers.dart`; screen data lives in a `@riverpod`
   notifier; controllers/focus/loading flags stay in widget `State`.
3. **Do not change how anything looks or animates** (visible changes approved so far: learn-part-step-1 added Learn to the Words top bar and one Learn button
   to the shared page; mnemonic-story added a settings button on the Words screen, the group line and group pager on the
   learn page, and the story, story runs and run details screens; get-words-from-subtitles-improvment added the "Get dialogues from
   subtitles" switch in Settings, the main screen pager with its dialogue pages, the dialogue pages and scene pictures on
   the shared page, the "Dialogs from movie" exercise and its dialogue screen; side-bar-for-main-screen adds the photo tab
   and photo panel on the main screen's words page and
   the highlighted word rows of a selected photo (look A, picked by the owner 2026-10-14); photo-panel-glass (owner, 2026-10-13) puts look A's tab and half-open
   panel on liquid glass (a frosted blur on Android) stuck to the screen edge with concave flares (which may cover the top bar) and turns every word row into one line, "word — translation", while the panel is open; share-formats (owner, 2026-10-14) makes "Share file" open a second sheet with five
   formats: Anki, CSV, PDF, Quizlet, Word list; side-panel-sources (owner, 2026-10-14) shows Quizlet sets and film subtitles as tiles in the half-open photo panel; learn-exercises (owner, 2026-10-14) changes the Learn list (H-10) and adds the exercise screens of learn-kit and each exercise spec; side-panel-previews (owner, 2026-10-15) makes the photo tab's third preview a mosaic of the third to sixth sources when there are more than three, and shows a film's poster on its tile; notes-page (owner, 2026-10-15) makes the half-open panel's expand control, and a drag to full-open, open the Notes page: one pager per panel source, picture in the middle as a hero from the panel, words to the right, a description/link/tags note (UI only) to the left; a drag widens the panel into that page, which then fades in; selecting a source scrolls its first row to the top; a film or set tile shows CC or the Quizlet logo with "N words" over its name, a poster instead when there is one; notes-editing (owner, 2026-10-15) keeps that note — a title above the description,
   any number of links, tags with suggestions from tags used before — puts the session's own tags above the list, opens a
   tapped photo full screen with zoom and lets a pinch zoom it in the pager, and opens a tapped words page as a dialog of
   the main screen's rows with the shared page's dashed "+ Add a word"). Keep `popup_menu_2`, `flutter_speed_dial`,
   `translator`, `http`. Move code into new files by cut-and-paste; do not rewrite it.
4. Secrets stay as constants in `lib/config/vocab_api_config.dart` (gitignored). No dart-define.
5. No new packages, no removed packages, no new domain models (approved: `Exercise` by learn-part-step-1; `WordGroup`, `StoryRun`, `StoryStep` and `WordPair.rowId` by mnemonic-story, ADR-0003; `FilmDialogue`, `WordGroup.dialogueId`,
   `StoryRun.kind` and `StoryRun.sceneText` by get-words-from-subtitles-improvment, ADR-0003; the package `liquid_glass_renderer`,
   pinned, by the owner for photo-panel-glass; the package `pdf`, pinned, and the Noto Sans font asset, by the owner
   for share-formats; `SourceKind.subtitles` by side-panel-sources (owner, 2026-10-14); `WordResult` on Session by learn-kit (owner, 2026-10-14, H-05); `SessionSource.title`, `.description`, `.links`,
   `.tags` and `Session.tags` by notes-editing (owner, 2026-10-15)), no `packages/` folder — ask first.
6. If a step cannot be done as written, stop and write what you found under that step in
   `docs/refactoring-plan.md`. Do not improvise a different structure.
7. Tests (`docs/testing.md`): while developing run `tool/test.sh smoke`; write tests for what you
   build and run them with `tool/test.sh changed`. Run the full regression (`tool/test.sh full`)
   only when the owner asks.

## Before finishing

```
dart run build_runner build --delete-conflicting-outputs
flutter analyze
tool/test.sh changed
grep -rn "Navigator.push\|MaterialPageRoute\|static final .* instance" lib
```
