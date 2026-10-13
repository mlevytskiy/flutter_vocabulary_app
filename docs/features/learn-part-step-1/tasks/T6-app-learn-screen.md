---
id: T6
title: "Add the app's learn page and LearnRoute"
layer: "ui"
deps: ["T2"]
acs: ["AC-04", "AC-06", "AC-07", "AC-13"]
files_hint: ["lib/router/routes.dart", "lib/router/routes.g.dart", "lib/features/learn/learn_screen.dart", "test/learn_screen_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T6 — Add the app's learn page and LearnRoute

## Why

[screens.md](../screens.md) SCR-03 (default, coming-soon tap, ticked, unticked again, start pressed (disabled)); [sad §4](../sad.md) "Mobile UI architecture" and "Which session the app's learn page reads"; [sad §6](../sad.md) S-01, S-02.

## What

- `lib/router/routes.dart` — `LearnRoute` nested under `WordsTableRoute` (`table`), carrying the same optional `sessionId`; regenerate `routes.g.dart`.
- `lib/features/learn/learn_screen.dart` — `StatefulWidget`; session from `wordInputNotifierProvider` (no `sessionId`) or `sessionByIdProvider(sessionId)` (read-only); count = `isFilled` rows; `CheckboxListTile` per exercise (`enabled: false` + subtitle "Coming soon" when unavailable); ticks in `State`; Start `ElevatedButton` with `onPressed: null` while nothing is ticked.
- `test/learn_screen_test.dart`.

## Definition of Done

**Done when:** `LearnRoute` (path `learn` under `table`, optional `sessionId`) builds `LearnScreen`, which shows "Learn", the session's word-to-learn count ("1 word" / "<n> words"), Step 1–3 with eleven tiles in plan order, only Mnemonic story tickable, ten greyed with "Coming soon", Start disabled with "Pick at least one exercise" until something is ticked; `test/learn_screen_test.dart` covers these states and a History `sessionId` showing that session's count without changing the current session.

- [ ] widget test: 11 tiles in AC-04 order under "Step 1/2/3", count text correct, nothing ticked, Start disabled, hint shown
- [ ] tapping a coming-soon tile, its box or its label changes nothing (AC-06)
- [ ] tick → Start enabled, hint hidden; untick → back (AC-07)
- [ ] with a History `sessionId` whose count differs from the current session: the History count is shown and the current session's provider state is unchanged (AC-13)
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Start's `onPressed` (push to coming-soon) arrives in T7 — here it may be a no-op while enabled; T7 replaces it.
- No new provider or notifier; ticks are transient UI state (architecture.md rule 2).
- Shares `routes.dart` with T7 → serialized lane.
