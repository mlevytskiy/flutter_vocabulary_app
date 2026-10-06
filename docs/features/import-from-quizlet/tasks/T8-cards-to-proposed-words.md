---
id: T8
title: "Turn cards into proposed words with the text rules, repeats and counts"
layer: "domain"
deps: []
acs: ["AC-04b", "AC-08", "AC-09", "AC-10"]
files_hint: ["lib/core/services/quizlet_cards.dart", "test/quizlet_cards_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T8 — Turn cards into proposed words with the text rules, repeats and counts

## Why

spec AC-04b, AC-08, AC-09, AC-10, §6 field length; [sad §4](../sad.md) card → proposed word; [sad §6 F3](../sad.md).

## What

- Pure Dart; output is `List<VocabWord>` (word, empty translation, description = definition) plus `skipped`, `found`, `stated`.

## Definition of Done

**Done when:** `proposeWords(cards, sessionWords, statedCount)` drops image-only cards, turns line breaks into "; ", cuts term and back to 500 characters ending with "…", builds the definition as back plus example on a new line, skips session words and repeats with the AC-10 equality rule keeping the first card, and returns the skipped count and the "Read X of Y" numbers (none when the page states no count); unit tests cover each AC case.

- [ ] unit tests pass, including a 600-character multi-line back and "Reluctant." vs "reluctant"
- [ ] `flutter analyze` clean

## Notes

- Found cards are counted before skipping (AC-08).
