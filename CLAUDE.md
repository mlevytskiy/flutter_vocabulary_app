# flutter_vocabulary_app — instructions for agents

Read `docs/architecture.md` first (short). If you are doing the restructuring, follow
`docs/refactoring-plan.md` one step at a time. Behaviour spec for the lightning icons:
`docs/lightning_icon_rules.md`. Server: `vocab-photo-api/` (Cloudflare Worker).

## Rules

1. Navigate only via typed routes in `lib/router/routes.dart`. No `Navigator.push`, no string paths.
2. Services come from providers in `lib/core/providers.dart`; screen data lives in a `@riverpod`
   notifier; controllers/focus/loading flags stay in widget `State`.
3. **Do not change how anything looks or animates.** Keep `popup_menu_2`, `flutter_speed_dial`,
   `screenshot`, `translator`, `http`. Move code into new files by cut-and-paste; do not rewrite it.
4. Secrets stay as constants in `lib/config/vocab_api_config.dart` (gitignored). No dart-define.
5. No new packages, no removed packages, no new domain models, no `packages/` folder — ask first.
6. If a step cannot be done as written, stop and write what you found under that step in
   `docs/refactoring-plan.md`. Do not improvise a different structure.

## Before finishing

```
dart run build_runner build --delete-conflicting-outputs
flutter analyze
grep -rn "Navigator.push\|MaterialPageRoute\|static final .* instance" lib
```
