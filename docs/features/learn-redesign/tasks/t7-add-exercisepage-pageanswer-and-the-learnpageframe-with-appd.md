---
id: T7
layer: ui
deps: ["T1"]
acs: ["AC-08", "AC-10"]
estimate: M
owner: "implementer agent"
status: todo
---

# T7 — Add ExercisePage/PageAnswer and the LearnPageFrame with AppDecor learnRight/learnWrong in every theme

**Derives from:** [spec](../spec.md) AC-08, AC-10 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

widget tests: frame shows step bar, 'N / M', chip, card, Check enabled only after ready(), verdict bar right/wrong with word — translation and Continue, done() skips Check; renders without overflow in all 5 themes at 393 pt, text scale 1.3

## Files

- `lib/features/learn/session/exercise_page.dart`
- `lib/features/learn/session/learn_page_frame.dart`
- `lib/core/theme/app_decor.dart`
- `lib/core/theme/themes/`
- `test/learn_session/learn_page_frame_test.dart`
