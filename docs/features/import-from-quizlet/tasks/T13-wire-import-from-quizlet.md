---
id: T13
title: "Add \"Import from Quizlet\" to the red + menu and keep the set as the words' source"
layer: "wiring"
deps: ["T4", "T5", "T12"]
acs: ["AC-01", "AC-03", "AC-13b", "AC-17"]
files_hint: ["lib/features/word_input/widgets/word_input_speed_dial.dart", "lib/features/word_input/word_input_screen.dart", "lib/features/word_input/word_input_notifier.dart", "test/quizlet_wiring_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T13 — Add "Import from Quizlet" to the red + menu and keep the set as the words' source

## Why

spec AC-01, AC-03, AC-13b, AC-17; [sad §5](../sad.md); [sad §6 F3](../sad.md) Done branch; [ADR-0005](../adr/0005-keep-photos-and-sets-in-one-source-list-with-a-kind.md).

## What

- Speed dial: `onImportFromQuizlet`, green, label "Import from Quizlet".
- Notifier: `upsertSetSource(id, name, url)`; screen: wires the flow's callbacks like the subtitle import.

## Definition of Done

**Done when:** The red + menu shows "Import from Quizlet" in green where Screenshot was and starts `runQuizletImport`; Done appends the kept words via `wordPairFromPhoto(w, sourceId: set id)` and adds the set source after the existing ones or renames the existing one for that set id, keeping its place; widget/notifier tests cover first import and re-import from another link shape.

- [ ] tests pass (menu item, words appended in set order with the set id, one set source after two imports, definition marked filled)
- [ ] `flutter analyze` clean, CLAUDE.md greps clean

## Notes

- Same files as T4/T5, so it runs after both.
