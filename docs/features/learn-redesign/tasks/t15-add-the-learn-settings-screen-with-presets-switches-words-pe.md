---
id: T15
layer: ui
deps: ["T6", "T14"]
acs: ["AC-17", "AC-18", "AC-19"]
estimate: M
owner: "implementer agent"
status: todo
---

# T15 — Add the Learn settings screen with presets, switches, words per session and Try it

**Derives from:** [spec](../spec.md) AC-17, AC-18, AC-19 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

widget tests: Balanced picked by default, preset sets switches, switch change → Custom, last switch of a step refused with the message, story/dialogue rows Try it only, Try it opens LearnRoute with that exercise ticked; reachable from the sheet's gear via LearnSettingsRoute

## Files

- `lib/features/learn/entry/learn_settings_screen.dart`
- `lib/features/learn/learn_screen.dart`
- `lib/router/routes.dart`
- `test/learn_session_learn_settings_test.dart`
