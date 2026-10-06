---
id: T7
title: "Add the app's coming-soon screen and make Start open it"
layer: "ui"
deps: ["T6"]
acs: ["AC-05", "AC-05b"]
files_hint: ["lib/router/routes.dart", "lib/router/routes.g.dart", "lib/features/learn/coming_soon_screen.dart", "lib/features/learn/learn_screen.dart", "test/learn_screen_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T7 — Add the app's coming-soon screen and make Start open it

## Why

[screens.md](../screens.md) SCR-03 (success, returned), SCR-04 (default, back); [sad §6](../sad.md) S-02; spec [AC-05, AC-05b](../spec.md).

## What

- `lib/router/routes.dart` — `ComingSoonRoute` nested under `LearnRoute`; regenerate.
- `lib/features/learn/coming_soon_screen.dart`.
- `lib/features/learn/learn_screen.dart` — Start → `ComingSoonRoute(...).push(context)`.
- Extend `test/learn_screen_test.dart` (or add `test/coming_soon_screen_test.dart`).

## Definition of Done

**Done when:** `ComingSoonRoute` (path `soon` under `learn`, exercise id) builds `ComingSoonScreen` with the exercise's name, "Coming soon — this exercise is not ready yet." and "Back to exercises" (pop); Start pushes it for the first ticked exercise in plan order; a widget test shows that Back to exercises and the back arrow both return with Mnemonic story still ticked, and that a new push of `LearnRoute` starts unticked.

- [ ] widget test with the real router: tick → Start → coming-soon text and heading shown; Back to exercises → learn page, still ticked; same with the back arrow (AC-05)
- [ ] leave to the Words screen and push `LearnRoute` again → nothing ticked (AC-05b)
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- The route is only reachable from Start, which offers available exercises only (SCR-04 N/A rows).
