---
id: T3
title: "Add the pure origin rules: derive type, edit flags, word change, episode from a file name, first line time"
layer: "domain"
deps: ["T2"]
acs: ["AC-02", "AC-03", "AC-04", "AC-05", "AC-07", "AC-08"]
files_hint: ["lib/core/words/word_origin_rules.dart", "test/word_origin_rules_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T3 — Add the pure origin rules: derive type, edit flags, word change, episode from a file name, first line time

## Why

Derives from [AC-02](../spec.md), [AC-03](../spec.md), [AC-04](../spec.md), [AC-05](../spec.md), [AC-07](../spec.md), [AC-08](../spec.md); pure rules first, so the import and edit tasks only call them.

## What

One pure Dart file and its tests.

## Definition of Done

- [ ] `originForRow(row, sources)` maps photo → image, subtitles → movie, set → set, none → manuallyEntered, with the film's name/season/episode
- [ ] `withEditedTranslation`, `withEditedDefinition` set the flags; `withChangedWord` clears context, kind, flags and `contextTried`, keeps type and movie fields
- [ ] `episodeFromFileName` parses `S02E05`, `s2e5`, `2x05`; returns empty otherwise
- [ ] `firstLineTime(word, timedLines)` returns the first whole-word match's start as `hh:mm:ss`, or empty
- [ ] tests in `test/word_origin_rules_test.dart`
- [ ] `flutter analyze` clean

## Notes

—
