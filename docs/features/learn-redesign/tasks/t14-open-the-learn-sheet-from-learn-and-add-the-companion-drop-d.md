---
id: T14
layer: ui
deps: ["T4", "T6", "T12"]
acs: ["AC-01", "AC-03", "AC-04", "AC-05", "AC-06", "AC-14", "AC-27"]
estimate: M
owner: "implementer agent"
status: todo
---

# T14 — Open the Learn sheet from Learn and add the companion drop-down beside it

**Derives from:** [spec](../spec.md) AC-01, AC-03, AC-04, AC-05, AC-06, AC-14, AC-27 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

widget tests: Learn looks as before and opens the sheet with word and due counts; no words → 'Add words with a translation to start learning'; split checkbox only at ≥ 20 words, remembered per collection, next-group line; Exercises starts the session; companion menu: alone ticked, teacher/friend disabled 'Soon'; LearnShareBar layouts still fit

## Files

- `lib/features/learn/entry/learn_sheet.dart`
- `lib/features/learn/entry/companion_button.dart`
- `lib/features/words_table/widgets/learn_share_bar.dart`
- `lib/features/words_table/words_table_screen.dart`
- `test/learn_session_learn_sheet_test.dart`
