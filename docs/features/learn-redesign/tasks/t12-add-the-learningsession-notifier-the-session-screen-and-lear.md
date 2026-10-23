---
id: T12
layer: app
deps: ["T4", "T5", "T6", "T8", "T9", "T10", "T11"]
acs: ["AC-02", "AC-08", "AC-09", "AC-11", "AC-16"]
estimate: L
owner: "implementer agent"
status: todo
---

# T12 — Add the LearningSession notifier, the session screen and LearningSessionRoute

**Derives from:** [spec](../spec.md) AC-02, AC-08, AC-09, AC-11, AC-16 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

notifier tests with fake page sources: types drawn min(3, on) per step, story/dialogue never drawn, pages built step by step, AI data in batches ≤ 19, error + Retry while data-free pages play, leave writes nothing; widget test: leave confirm text; typed route only

## Files

- `lib/features/learn/session/learning_session_notifier.dart`
- `lib/features/learn/session/learning_session_screen.dart`
- `lib/features/learn/session/page_registry.dart`
- `lib/router/routes.dart`
- `test/learn_session/learning_session_test.dart`
