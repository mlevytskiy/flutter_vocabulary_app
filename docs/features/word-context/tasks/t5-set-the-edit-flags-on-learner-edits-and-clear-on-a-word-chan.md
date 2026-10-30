---
id: T5
title: "Set the edit flags on learner edits and clear on a word change"
layer: "app"
deps: ["T3"]
acs: ["AC-04", "AC-05"]
files_hint: ["lib/features/words/words_notifier.dart", "lib/features/words/widgets/translation_dots_button.dart", "lib/features/words/widgets/definition_dots_button.dart", "test/word_edit_flags_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T5 — Set the edit flags on learner edits and clear on a word change

## Why

Derives from [AC-04](../spec.md), [AC-05](../spec.md); owner B4 and B5.

## What

Words notifier and the two dots buttons' pick handlers.

## Definition of Done

- [ ] `words_notifier.dart`: a translation or definition change from the field or the ⋯ option list applies `withEditedTranslation/Definition`; lightning fills and imports do not
- [ ] an English word change applies `withChangedWord` (where `translationOptionsJson` is dropped today)
- [ ] tests in `test/word_edit_flags_test.dart`
- [ ] `flutter analyze` clean

## Notes

—
