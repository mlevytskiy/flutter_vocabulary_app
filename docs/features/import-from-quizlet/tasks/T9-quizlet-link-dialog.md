---
id: T9
title: "Build the Quizlet link dialog that refuses text without a set link"
layer: "ui"
deps: ["T6"]
acs: ["AC-01", "AC-06"]
files_hint: ["lib/features/word_input/widgets/quizlet_link_dialog.dart", "test/quizlet_link_dialog_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T9 — Build the Quizlet link dialog that refuses text without a set link

## Why

spec AC-01, AC-06; [ux-flows](../ux-flows.md) SCR-02; [sad §6 F1](../sad.md).

## What

- Modelled on `subtitle_import_dialog.dart` (same dialog structure and buttons); message constant in a `QuizletImportMessages` class.

## Definition of Done

**Done when:** The dialog asks for a Quizlet set link, Start with text holding no set link shows the refusal and keeps the text, Start with a set link returns `QuizletSetLink`, closing returns null; widget tests cover the three cases.

- [ ] widget tests pass
- [ ] `flutter analyze` clean

## Notes

- Dialogs are not routes (CLAUDE.md rule 1).
