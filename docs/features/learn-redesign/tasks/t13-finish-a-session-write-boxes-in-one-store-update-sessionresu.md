---
id: T13
layer: ui
deps: ["T12"]
acs: ["AC-07", "AC-12", "AC-13", "AC-16"]
estimate: M
owner: "implementer agent"
status: todo
---

# T13 — Finish a session: write boxes in one store update, SessionResult holder and the results screen with Practise shaky and Next group

**Derives from:** [spec](../spec.md) AC-07, AC-12, AC-13, AC-16 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

tests: finishing calls store.update once and boxes move per AC-13; erased collection → results shown with nothing written; results lists known/shaky/new with next review text; Practise N shaky starts a session on those rows; Next group shown only when split

## Files

- `lib/features/learn/session/session_result.dart`
- `lib/features/learn/session/session_results_screen.dart`
- `lib/features/learn/session/learning_session_notifier.dart`
- `lib/router/routes.dart`
- `test/learn_session_session_results_test.dart`
