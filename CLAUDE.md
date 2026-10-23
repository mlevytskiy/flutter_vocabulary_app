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
   the main screen's rows with the shared page's dashed "+ Add a word"; collections-screen (owner, 2026-10-16) adds
   the Collections screen, the recycle bin, the edit button beside the main screen's title, the collection's name as the
   main screen's title, the side menu always being there with its new Collections item, the ⋮ menu button on every icon,
   the recycle-bin drop zone shown during a drag, the name in History rows, on the shared page and in shared files' names
   and titles, the share sheet's warning that the name is public, "collection" replacing "session" in every text, and (owner,
   2026-10-16, T23) on phone widths the shared page's title row wraps and its h1 breaks long names, with the tab title
   "<name> — N words"; collections-restyle (owner, 2026-10-16) gives the Collections screen the Stitch
   folder and document icons with a corner badge per kind of source (Quizlet, film, photo), removes the ⋮ buttons,
   the long-press Rename/Delete menu, the top bar's New folder / New collection icons, the recycle-bin tile, the
   drop zone shown during a drag and, at the top level, the "↑ Up  Collections" line, and adds three round buttons
   like the main screen's: Settings, the recycle bin (also the drop target to delete) and a plus with New folder
   and New collection; a tap on the recycle bin opens a dialog with "Go to recycle bin" and "Enable/Disable
   delete mode", where every icon shows a small round bin button whose tap flies the
   picture into the recycle-bin button (it bounces) and bins the item without asking (owner, 2026-10-17: the current
   collection shows the bin button too, in every theme the old blue-grey circle with a white bin, and its tap only shows
   the "cannot be deleted" snackbar; the recycle-bin button's icon is full while the bin holds something, empty
   otherwise, whatever delete mode); every top bar takes the main screen's word-row colour (`topBarColor` in `lib/app.dart`);
   the session → collection rename of classes, fields, files and providers, with stored names pinned, is an approved
   exception to "move code, do not rewrite it" (collections-screen ADR-0002); collection-tags (owner via Fable 5.1 proxy, 2026-10-16) adds the Collection details sheet (name, description, origin and topic tag fields) for New collection and the main screen's edit button, the tag line under the main screen's top bar, typed tag fields with suggestion rows and Forget on the Notes page, and search, the filter sheet, the flat result list and filter chips on the Collections screen; words-photo-panel (owner, 2026-10-16) adds the photo tab and photo panel to the Words screen, as on the main screen, and moves the Words screen's "Include photos (N)" switch into the Words screen's settings (owner, 2026-10-19: on the Words screen the open panel no longer turns the table into one-line rows — the table stays, a selected source's rows are highlighted in it and its first row scrolls to the top; the photo tab and panel stay where they stand while a route slides or zooms in or out, so the tab stays on screen from the main screen to the Words screen and back, and the tab's height counts from the top bar's bottom edge, above the main screen's tag line); tag-field-restyle (owner,
   2026-10-17) turns each tag field into one rounded box with a view state (tinted, kind label, chips without delete)
   and an edit state (accent border, Done check, chips with delete), drops the helper line and the suggestion chip row,
   and shows the autocomplete only while typing, with the typed part bold and an `Add "…"` row for a new tag; the
   owner, 2026-10-17, then took the icons off every tag, put the kind's question on top of the box and opened the
   Collection details sheet's tag fields in the edit state; app-themes (owner, 2026-10-17) adds "App settings" below
   History in the side menu, the App settings page with its theme gallery, and four themes — Classic (the default: the
   colours from before with Matcha's fonts, text colours and top-bar title size, owner 2026-10-17), Aurora, Matcha and Amber Terminal (owner, 2026-10-17, cut from ten), and Windows 95 (owner, 2026-10-17: teal desktop, grey bevelled rows, navy title bar, square corners, the platform font) — that recolour every screen,
   its icons and the Collections pictures (outlines only in Amber Terminal) and change fonts, row shapes, blur and
   backdrops through `AppDecor` in `lib/core/theme/app_decor.dart`, one file per theme in `lib/core/theme/themes/`; a new hard-coded colour goes there as a slot; new-user-trial (owner, 2026-10-17) adds the App settings card "Try the app as a new user" with "Start as a new user", which puts all data aside and restarts the app empty, and, while that is on, "Restore my data", which deletes the trial's data and brings the saved data back, each behind a confirm dialog; while the trial is on, a 4 px red line runs along the top of every screen, over the top bar's top edge (owner, 2026-10-17);
   collections-search (owner, 2026-10-17) shows the Collections filter icon only in search (or while a filter is on),
   the hint "Search in <folder>", the search list of only the open folder's level with its matching folders, the "Match
   outside" sheet (peeking at 20%, opening on the route with "You are here", opening by itself when the list is empty),
   the round buttons hidden while that sheet shows, and live tag counts with disabled 0 chips in the filter sheet);
   filter-sheet-pills (owner, 2026-10-18) rebuilds the Collections filter sheet: one tag field for both kinds with
   autocomplete (each suggestion with its kind and live count), a Popular line of four tags (two recently applied, then
   the most used; hidden with four tags or fewer), Created and Edited as two dropdown pills side by side, Sort as a pill
   beside Reset, the sheet sized to its content with a drag handle, and a refused range shown under the pills;
   classic-purple (owner, 2026-10-18) gives Classic the Next button's purple where it had Matcha's dark green (row
   text, dark icons) and lilac greys for Matcha's grey greens; collection-naming (owner, 2026-10-18) names a
   collection nobody named "Vocabulary" ("Vocabulary 1", "Vocabulary 2", … when taken) and, once it has 5 words,
   the AI's short name (Worker `POST /collections/name`, Sonnet 5.5), which the main screen's title reveals letter
   by letter; (owner, 2026-10-19: as a swirl float — the old name stays during the request, then its letters swirl up and away while the new ones swirl up into place, overlapping, so the title is never empty); a name the learner typed is never replaced; New collection's name is optional, labelled
   "Name (optional)" with a pale grey hint "Leave empty to let AI name it" and, while empty, a sparkle note
   under it; likewise a description nobody wrote stays empty until 20 words, then AI writes it (Worker
   `POST /collections/description`), with the hint "Leave empty to let AI write it" and its note in New collection; the main screen's edit button
   shows the same optional name, hints and notes for a name or description nobody gave (owner, 2026-10-18);
   the Collection details sheet's Create/Save is a full-width button in a bar pinned at the bottom, above the
   keyboard, and the AI notes are helper lines (the description's beside its counter) in a per-theme
   `AppDecor.aiAccent` with no box (owner, 2026-10-18); at launch the collections from before, and any still
   waiting, get their AI names and descriptions from one request, `POST /collections/autofill` (owner, 2026-10-18);
   the Collections screen's Settings button opens its own Collections settings screen with one row, "Replace all
   date names", which renames every "17.10.2026 17:05" name by those rules in one request and says what it did in a
   snackbar (owner, 2026-10-18); inside a folder the Collections screen's Up is an arrow in the top bar's leading
   slot and the path is the bar's title on one line (the open folder in the title style, the levels above smaller
   and grey, a long path scrolling sideways to its end) in place of the row below the bar (owner, 2026-10-18); the
   recycle-bin button lights up and takes the drop as soon as any part of a dragged icon, its name too, covers it,
   not only the point under the finger (owner, 2026-10-18); the Words speed dial's "From subtitles" button takes an active colour per theme in place of its grey (owner, 2026-10-18); navigation (owner, 2026-10-18) makes Collections the
   start screen and the side menu's first item, gives every screen the menu opens (Collections, Words, App settings) the
   side menu behind a menu button instead of Back, renames the menu's "Main" to "Words", removes History with its
   menu item, and makes Back on Words or App settings go to Collections; the main screen's code is `words`
   (`WordsScreen`, `WordsRoute`, `/words`), the table's stays `words_table`); start-screen (owner, 2026-10-18) opens a cold start on Words when the app was left less than 5 minutes ago or the only collection is empty, on Collections otherwise (`lib/router/start_location.dart`), and the Words screen opens without the keyboard. While searching, the Collections top bar's leading slot is a ← "Close search" (as Back: the text and filters go, the folder view comes back) and the field shows a ✕ "Clear text" while it has text (owner, 2026-10-18). Every top bar puts its title right after the menu or Back button with the Words screen's spacing (48 px leading, no title gap: `barLeadingWidth`/`barTitleSpacing` in `lib/core/theme/theme_kit.dart`), and Collections' search keeps its icons where they were (owner, 2026-10-18). The side menu's three screens stay alive in one shell: a menu tap lets the drawer slide shut over the current screen, then the other one shows as it was left, with no page transition (owner, 2026-10-19). Every phone lays out as the 393 pt iPhone 15/16: a narrower screen draws that layout scaled down, a wider one is left as it is (`LayoutScale`, `lib/core/widgets/layout_scale.dart`; owner, 2026-10-19). liquid-glass-tuning (owner, 2026-10-19) adds a Liquid glass section with Thickness, Bending and Blur sliders (percent of the looks' values) and Reset to the Settings screen of the Words screen's round settings button, iOS only, scaling the photo tab's and the half-open panel's liquid glass. Android pages push and pop with the iOS slide
   (`pageTransitions` in `lib/app.dart`; owner, 2026-10-19). learn-redesign (owner via Fable 5.1 proxy, 2026-10-23) keeps the Learn button as it is and adds a companion drop-down button beside it (Learn alone; With teacher and With friend greyed "Soon"), makes Learn open the Learn sheet (Exercises and Talk with AI cards, word and due counts, a settings gear, and from 20 words a remembered "Split words into groups of 7–12" checkbox with the next group's line), and adds the learning session screen in one card-and-check page frame (step bar, page counter, verdict bar; `AppDecor.learnRight`/`learnWrong`), its leave dialog, the session results screen, the Learn settings screen (presets, switches, words per session, Try it; the old Learn page opens only from Try it), and the Talk with AI screen with hold-to-talk, and (owner, 2026-10-24) a "Speech recognition" choice in Learn settings between speech_to_text and speech_to_text_pro. Keep `popup_menu_2`, `flutter_speed_dial`,
   `translator`, `http`. Move code into new files by cut-and-paste; do not rewrite it.
4. Secrets stay as constants in `lib/config/vocab_api_config.dart` (gitignored). No dart-define.
5. No new packages, no removed packages, no new domain models (approved: `Exercise` by learn-part-step-1; `WordGroup`, `StoryRun`, `StoryStep` and `WordPair.rowId` by mnemonic-story, ADR-0003; `FilmDialogue`, `WordGroup.dialogueId`,
   `StoryRun.kind` and `StoryRun.sceneText` by get-words-from-subtitles-improvment, ADR-0003; the package `liquid_glass_renderer`,
   pinned, by the owner for photo-panel-glass; the package `pdf`, pinned, and the Noto Sans font asset, by the owner
   for share-formats; `SourceKind.subtitles` by side-panel-sources (owner, 2026-10-14); `WordResult` on Session by learn-kit (owner, 2026-10-14, H-05); `SessionSource.title`, `.description`, `.links`,
   `.tags` and `Session.tags` by notes-editing (owner, 2026-10-15); `Session` renamed `WordCollection` with `name`,
   `folderId`, `order`, `binnedAt`, `binnedFromFolderId`, `keep`, and the new Isar collection `CollectionFolder` by
   collections-screen (owner, 2026-10-16, ADR-0003/0004/0005), no packages; `WordCollection.description`, `WordCollection.originTags`/`.topicTags`, `SessionSource.originTags`/`.topicTags`, the enum `TagKind` and the Isar collection `TagLibraryEntry` by collection-tags (owner via Fable 5.1 proxy, 2026-10-16), no packages; the OFL
   font assets Comfortaa, JetBrains Mono, Manrope, Nunito and Unbounded by app-themes (owner,
   2026-10-17), no packages; `WordCollection.nameKind` and the enum `NameKind` by collection-naming (owner,
   2026-10-18) and `WordCollection.descriptionKind` (owner, 2026-10-18), no packages; `WordBox` and `WordCollection.boxes` (the Leitner box record) and the package `speech_to_text`, pinned, by learn-redesign (owner via Fable 5.1 proxy, 2026-10-23); the package `speech_to_text_pro` 0.0.1, pinned, as a second speech engine picked in Learn settings (owner, 2026-10-24)), no `packages/` folder —
   ask first.
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
