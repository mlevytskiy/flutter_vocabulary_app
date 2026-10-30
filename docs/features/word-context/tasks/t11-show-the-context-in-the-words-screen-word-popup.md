---
id: T11
title: "Show the context in the Words screen word popup"
layer: "ui"
deps: ["T1", "T2"]
acs: ["AC-13"]
files_hint: ["lib/features/words/widgets/translation_options_content.dart", "test/word_popup_context_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T11 — Show the context in the Words screen word popup

## Why

Derives from [AC-13](../spec.md); owner B10 (approved visible change), proxy Q14, Q16.

## What

One widget change.

## Definition of Done

- [ ] `translation_options_content.dart` shows the row's context, read-only, under the options
- [ ] reuses `AppDecor.aiAccent` and the sparkle of collection-naming; no new colour
- [ ] widget test in each of two themes
- [ ] `flutter analyze` clean

## Notes

—
