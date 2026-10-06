---
id: T12
title: "Run a Quizlet import from link to kept words, with translation and the late-result rule"
layer: "app"
deps: ["T8", "T9", "T10", "T11"]
acs: ["AC-02", "AC-03", "AC-04", "AC-04b", "AC-07", "AC-07b", "AC-16", "AC-17"]
files_hint: ["lib/features/word_input/quizlet_import_flow.dart", "test/quizlet_import_flow_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T12 — Run a Quizlet import from link to kept words, with translation and the late-result rule

## Why

[sad §6 F2, F3](../sad.md); spec AC-02, AC-03, AC-04, AC-04b, AC-07, AC-07b, AC-16; precedent `subtitle_import_flow.dart`.

## What

- Same shape as `runSubtitleImport` (`currentSessionId`, `sessionWords`, `addWords` callbacks); `QuizletImportMessages` for the AC-07 text.
- Translation via `googleTranslateServiceProvider`, bounded concurrency 6; Cancel during translation stops it.

## Definition of Done

**Done when:** `runQuizletImport` opens the link dialog, the progress dialog, proposes words, translates terms through `translateWord` at most 6 at a time (a failed term left empty), drops the result when the session changed (checked before the results dialog and at Done), shows the failure message on AC-07 and nothing on cancel, and calls `addWords` with the kept words and the set (id, name, plain link) only on Done with ≥1 word; flow tests with fakes cover each branch.

- [ ] flow tests pass (happy, no new words, removed all, closed, session changed before dialog and at Done, failure, cancel during reading and during translation)
- [ ] `flutter analyze` clean

## Notes

- Session words come in through `sessionWords()` for AC-10 (T8).
