---
id: T18
layer: ui
deps: ["T14", "T17"]
acs: ["AC-20", "AC-21", "AC-24"]
estimate: M
owner: "implementer agent"
status: todo
---

# T18 — Add the Talk with AI screen and TalkRoute, opened from the Learn sheet

**Derives from:** [spec](../spec.md) AC-20, AC-21, AC-24 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

widget tests: bubbles, word strip ticks, Hint after 2, End talk → results with 'N words not used — unchanged', day-limit and error states, sheet's Talk with AI card opens it

## Files

- `lib/features/learn/talk/talk_screen.dart`
- `lib/features/learn/entry/learn_sheet.dart`
- `lib/router/routes.dart`
- `test/learn_session_talk_screen_test.dart`
