# flutter_vocabulary_app — instructions for agents

Always read `docs/architecture.md` (rules, how the pieces talk, checklist) and `docs/testing.md`.
Server: `vocab-photo-api/` (Cloudflare Worker). Read these only when your task needs them:

- it changes how something looks or animates, or adds a package or domain model →
  `docs/approved-changes.md` (everything the owner approved so far, with feature and date)
- it touches the lightning icons → `docs/lightning_icon_rules.md`
- you need to know where a file lives → `docs/folder-layout.md` (or grep)
- it touches the Quizlet import, mnemonic story, film dialogues or talk missions →
  `docs/architecture-features.md`

## Rules

1. Navigate only via typed routes in `lib/router/routes.dart`. No `Navigator.push`, no string paths.
2. Services come from providers in `lib/core/providers.dart`; screen data lives in a `@riverpod`
   notifier; controllers/focus/loading flags stay in widget `State`.
3. **Do not change how anything looks or animates** unless the current feature's spec approves it
   or `docs/approved-changes.md` lists it. A new approval is recorded there (feature, owner, date),
   not here. A new hard-coded colour goes into `AppDecor` (`lib/core/theme/app_decor.dart`) as a
   slot, one file per theme in `lib/core/theme/themes/`. Keep `popup_menu_2`, `flutter_speed_dial`,
   `translator`, `http`. Move code into new files by cut-and-paste; do not rewrite it.
4. Secrets stay as constants in `lib/config/vocab_api_config.dart` (gitignored). No dart-define.
5. No new packages, no removed packages, no new domain models, no `packages/` folder — ask first.
   `pubspec.yaml` is the approved package set; the approved models and packages are listed in
   `docs/approved-changes.md`, and a new approval is recorded there.
6. If a task cannot be done as written, stop and write what you found in the task's file (or tell
   the owner). Do not improvise a different structure.
7. Tests (`docs/testing.md`): while developing run `tool/test.sh smoke`; write tests for what you
   build and run them with `tool/test.sh changed`. Run the full regression (`tool/test.sh full`)
   only when the owner asks. `tool/test.sh -q …` prints only the summary and the failures.

## Before finishing

```
dart run build_runner build --delete-conflicting-outputs
flutter analyze
tool/test.sh -q changed
grep -rn "Navigator.push\|MaterialPageRoute\|static final .* instance" lib
```
