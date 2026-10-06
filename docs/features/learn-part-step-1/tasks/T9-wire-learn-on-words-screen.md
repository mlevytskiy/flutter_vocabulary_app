---
id: T9
title: "Put Learn on the Words screen: SnackBar when empty, otherwise open the learn page"
layer: "wiring"
deps: ["T6", "T8"]
acs: ["AC-01", "AC-02", "AC-03", "AC-13"]
files_hint: ["lib/features/words_table/words_table_screen.dart", "test/words_table_learn_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T9 — Put Learn on the Words screen: SnackBar when empty, otherwise open the learn page

## Why

[screens.md](../screens.md) SCR-02 (empty, success); [sad §6](../sad.md) S-01; spec [AC-01, AC-02, AC-03, AC-13](../spec.md).

## What

- `lib/features/words_table/words_table_screen.dart` — replace the Share action with `LearnShareBar`, passing the existing Share handler unchanged and a Learn handler that mirrors Share's empty check.
- `test/words_table_learn_test.dart`.

## Definition of Done

**Done when:** The Words screen's `AppBar` uses `LearnShareBar`; Learn shows the `SnackBar` "No words to learn" when no row `isFilled` and otherwise pushes `LearnRoute(sessionId: <this screen's sessionId>)`; a widget test covers the empty SnackBar, opening from the current session and from a History session (its count, current session unchanged) and the back arrow returning to the same Words screen.

- [ ] empty session: tap Learn → SnackBar "No words to learn", still on the Words screen (AC-03)
- [ ] current session with words: Learn → learn page; back → same Words screen (AC-02)
- [ ] History session: learn page shows its count; `wordInputNotifierProvider`'s current session id and rows are unchanged (AC-13)
- [ ] Share still behaves as before ("No words to share" when empty)
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Navigation only via the typed route (CLAUDE.md rule 1); the SnackBar is not a route.
