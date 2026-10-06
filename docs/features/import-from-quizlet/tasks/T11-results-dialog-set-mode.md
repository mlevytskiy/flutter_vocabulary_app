---
id: T11
title: "Show the set name, \"Read X of Y\", skipped cards and \"No new words\" in the results dialog"
layer: "ui"
deps: []
acs: ["AC-02", "AC-04b", "AC-08"]
files_hint: ["lib/features/word_input/widgets/vocab_result_dialog.dart", "test/vocab_result_dialog_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T11 — Show the set name, "Read X of Y", skipped cards and "No new words" in the results dialog

## Why

spec AC-02, AC-04b, AC-08; [ux-flows](../ux-flows.md) SCR-04; [sad §6 F3](../sad.md).

## What

- A third entry point next to `showVocabResultDialog` / `showSubtitleResultDialog`, same `_showResultDialog` base; photo and subtitle dialogs unchanged.

## Definition of Done

**Done when:** `showQuizletResultDialog` reuses the results dialog with the set's name on top, the "Read X of Y cards" line only when fewer than stated, the "N cards skipped…" line only when some were skipped, and "No new words in this set." when the list is empty, Done then returning an empty list; widget tests cover each line.

- [ ] widget tests pass
- [ ] existing result-dialog tests still pass
