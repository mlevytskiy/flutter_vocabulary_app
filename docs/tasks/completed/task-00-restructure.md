# Task 00 — Restructure: feature folders, go_router, Riverpod, persistence (wave 0)

|  |  |
|---|---|
| **Roadmap step** | — (enabler: stops every later task colliding on one 1,300-line file) |
| **Size** | M, as 5 S/M steps that each ship independently |
| **Wave** | 0 — after task-01, before everything else |
| **Depends on** | task-01 (app half is done; finish the Worker half first or in parallel — disjoint files) |
| **Blocked on** | — |
| **Unlocks** | task-03 (step 3 of the plan *is* task-03), parallel work on 02/04/08 |
| **Files** | `lib/**` (moves), `lib/router/` (new), `lib/core/providers.dart` (new), `lib/core/services/word_store.dart` (new), `lib/features/word_input/word_input_notifier.dart` (new), `pubspec.yaml`, `test/word_store_test.dart` |
| **Status** | done (`9a0deb4`, `5e18846`, `9da9291`, docs commit for step 5) |

## Prompt

Read `CLAUDE.md`, then `docs/architecture.md`, then `docs/refactoring-plan.md`. Execute the
refactoring plan **one step per session or PR**, in order, starting at step 1. Each step's *Do*
list is the instruction, its *Done when* the acceptance criterion, its *Commit* line the message.

This is a structural move, not a redesign. The plan's "Behaviour that must not change" list is
checked on device after **every** step; items 2 (the `popup_menu_2` dots popup) and 4 (the
`flutter_speed_dial` FAB — same animation, same icon sizes) are where the previous attempt
regressed, so look at them first. Code is cut and pasted into new files, not rewritten; no package
is added beyond the seven the plan names, none removed; the API secret stays a constant in
`lib/config/vocab_api_config.dart`; no new models, no `packages/` folder.

If a step cannot be done as written, append `### Findings` under that step in
`docs/refactoring-plan.md` with what blocked it and what you propose, and stop.

## Acceptance criteria

- [x] **AC-1** `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test` all exit 0. (5 pre-existing info-level lints remain, unrelated to this task — see `docs/refactoring-plan.md`'s "What changed".)
- [x] **AC-2** `grep -rn "Navigator.push\|MaterialPageRoute\|static final .* instance" lib` matches nothing except the documented `PhotoScaler.instance` exception.
- [x] **AC-3** `find lib -name "*.dart"` matches the tree in `docs/architecture.md` §1; `lib/screens`, `lib/services`, `lib/models`, `lib/widgets` no longer exist; no `packages/` directory.
- [x] **AC-4** `pubspec.yaml` diff against `master` before the task adds exactly `go_router`, `go_router_builder`, `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`, `shared_preferences` and removes nothing.
- [x] **AC-5** On device, all 8 items of "Behaviour that must not change" pass — the popup and the FAB are pixel-for-pixel what they were. (The dots popup's *options* are still the pre-existing hardcoded stub, unrelated to this task — see task-01's note.)
- [x] **AC-6** Persistence: 5 pairs → force-quit → reopen → 5 rows + one blank, focus in the blank; 3× repeat with no growth; photo-added words survive. **Not explicitly checked:** typing then immediately backgrounding (not force-quitting) keeps the last characters — the `didChangeAppLifecycleState(paused)` → `flush()` path should cover it (the same code path force-quit exercises), but the user chose to skip this specific manual check as redundant with the force-quit tests already done. Worth a quick check if this ever regresses.
- [x] **AC-7** `docs/refactoring-plan.md` ends with a filled-in `## What changed` section.
