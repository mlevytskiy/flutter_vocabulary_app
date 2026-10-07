---
id: T18
title: "Add the Words settings button and screen with the three AI choices"
layer: "ui"
deps: ["T12", "T13"]
acs: ["AC-12", "AC-13"]
files_hint: ["lib/router/routes.dart", "lib/router/routes.g.dart", "lib/features/words_settings/words_settings_screen.dart", "lib/features/words_table/words_table_screen.dart", "test/words_settings_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T18 — Add the Words settings button and screen with the three AI choices

## Why

[ux-flows](../ux-flows.md) SCR-02, SCR-05 and Flow US-03; [sad §6](../sad.md) S-06; [ADR-0004](../adr/0004-serve-the-offered-ai-list-with-prices-from-the-worker.md).

## What

- A settings button on the Words screen that looks like the main screen's settings button (same icon and style), pushing `WordsSettingsRoute` under `table`.
- Three choices (story writer, picture prompt writer, picture maker) from `offeredAisProvider`. Text AIs show "≈ $X (estimate)" until they have finished steps of that role, then "$X average · N runs"; picture makers show their price per picture. "<AI name> is no longer available" when a choice fell back. A "Story runs" entry.
- The choice is saved through `aiChoiceProvider`.

## Definition of Done

**Done when:** Widget tests in `test/words_settings_test.dart` show the three choices with estimate and average prices computed per role, the fallback message for an unlisted choice, and the choice kept after rebuilding the providers.

- [ ] the settings button matches the main screen's button
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Shares `routes.dart` with T17/T19 and `words_table_screen.dart` with T16 (serialized).
