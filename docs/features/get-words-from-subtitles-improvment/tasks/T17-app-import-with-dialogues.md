---
id: T17
title: "Carry dialogues from the subtitle import to Done and save them with the words"
layer: "app"
deps: ["T4", "T14", "T16"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-07", "AC-08", "AC-09", "AC-10", "AC-12", "AC-23"]
files_hint: ["lib/core/services/subtitle_words_service.dart", "lib/features/word_input/subtitle_import_flow.dart", "lib/features/word_input/word_input_notifier.dart", "test/subtitle_import_dialogues_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T17 — Carry dialogues from the subtitle import to Done and save them with the words

## Why

[sad §6](../sad.md) critical flow 1, [ADR-0002](../adr/0002-pick-words-and-dialogues-in-one-ai-request.md), [sad §4](../sad.md) "Results dialog unchanged".

## What

- `pickWords` sends `dialogues: true` only when the setting is on, and parses `dialogues` into the result. A missing field from an old Worker means none (AC-07).
- `runSubtitleImport` keeps the dialogues with the result. The results dialog is unchanged. At Done, in the session the import started in, it calls a new notifier method `addWordsWithDialogues`.
- `addWordsWithDialogues` adds the kept words, applies `atDone`, appends the dialogues after the existing ones with a new `importId`, the import's row ids and pending delivery when the session has a link, all in one save (AC-03, AC-10).
- Failures, no-English and a changed session drop words and dialogues as today (AC-08, AC-09, AC-12).

## Definition of Done

**Done when:** With the setting off the request has no `dialogues` key and Done adds only words; with it on Done saves words and filtered dialogues in one session save; a changed session drops both.

- [ ] flow tests with a fake service for on / off / no dialogue qualifies / failure / changed session
- [ ] an assertion that the off request JSON equals today's
- [ ] `flutter analyze` clean

## Notes

- Shares `word_input_notifier.dart` with T18 (one lane).
- As built (implement, 2026-10-13): the words still go in through the screen's `_addWordsFromPhoto` (it owns the row controllers), and the dialogues right after through `WordInputNotifier.addImportDialogues(dialogues, keptCount)`, which links them to the last `keptCount` rows. Both changes are synchronous, so the one debounced write saves them together. Feature tests: `subtitle_import_dialogues_test.dart`, `subtitle_words_service_test.dart`, `subtitle_import_flow_test.dart`.
