---
id: T18
title: "Apply the edit rule to dialogues whenever a word changes or is deleted"
layer: "app"
deps: ["T14", "T17"]
acs: ["AC-11", "AC-26"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "test/dialogue_edits_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T18 — Apply the edit rule to dialogues whenever a word changes or is deleted

## Why

[sad §4](../sad.md) choice 3, spec AC-11 and AC-26.

## What

- Every notifier path that changes or removes a word row (update, remove, reorder, add) runs `afterEdit` in the same save.
- Adding a row never adds it to a dialogue.

## Definition of Done

**Done when:** Deleting a dialogue word, editing it out of the text, editing its translation, and deleting every word of a dialogue each leave the session in the AC-11/AC-26 state after one save.

- [ ] notifier tests for each case
- [ ] existing word input notifier tests green
- [ ] `flutter analyze` clean

## Notes

- None.
