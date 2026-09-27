---
id: T10
title: "Keep per-row definition state in the input screen and notifier"
layer: "app"
deps: ["T1"]
acs: ["AC-11", "AC-13"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "lib/features/word_input/word_input_notifier.dart", "lib/features/word_input/word_input_notifier.g.dart", "test/word_input_notifier_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T10 — Keep per-row definition state in the input screen and notifier

## Why

Derives from [sad §5, §8 "Data never deleted by mode"](../sad.md) and [spec AC-11](../spec.md).

## What

Add a definition controller, focus node, `_isLoadingDefinition`, `_definitionMarkedFilled` and definition options to the screen's parallel per-row lists, created/restored/reordered/removed/pushed in the same places as the translation ones. The notifier saves and restores definitions. Editing the word drops definition options (senses) but keeps the definition text (spec §8 resolved). The definition focus node counts toward "row in focus". No visible change yet.

## Definition of Done

- [ ] Notifier tests: definition saved and restored; reorder and remove keep definitions aligned with their words.
- [ ] Test: editing the word clears stored senses, keeps definition text.
- [ ] Existing widget tests (dots close race, row-0 identity) still pass.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Largest risk area (sad §11 row 3). No layout change in this task.
