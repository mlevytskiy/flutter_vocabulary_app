---
id: T17
layer: app
deps: ["T3", "T4", "T13", "T16"]
acs: ["AC-20", "AC-21", "AC-22", "AC-24"]
estimate: L
owner: "implementer agent"
status: todo
---

# T17 — Add the talk API service, the pure talk rules and the Talk notifier

**Derives from:** [spec](../spec.md) AC-20, AC-21, AC-22, AC-24 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

tests with a fake API: words from the word picker, scene priority (story text, dialogue, name+description), only learner text ticks words, hint after 2 replies without target, ends after 12 replies or all used, Done scores used/hinted/unused per AC-22 via applySession, day limit message, typed text kept on error

## Files

- `lib/core/services/talk_api_service.dart`
- `lib/core/providers.dart`
- `lib/features/learn/talk/talk_rules.dart`
- `lib/features/learn/talk/talk_notifier.dart`
- `test/learn_session_talk_test.dart`
