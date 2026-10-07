---
id: T13
title: "Port the matching rule to Dart and test it against the Worker's case file"
layer: "domain"
deps: ["T2"]
acs: ["AC-05", "AC-11"]
files_hint: ["lib/core/dialogues/dialogue_match.dart", "test/dialogue_match_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T13 — Port the matching rule to Dart and test it against the Worker's case file

## Why

[sad §4](../sad.md) "One matching rule, two languages", [sad §8](../sad.md).

## What

- Pure `matchPlaces(text, word)` and `appears(text, word)`, with the same tokenizer and endings as `word-check.ts`.
- The test reads `vocab-photo-api/src/story/match-cases.json` and checks every case, so the two languages cannot drift.

## Definition of Done

**Done when:** Every case in `match-cases.json` gives the same places in Dart as in TypeScript.

- [ ] `dialogue_match_test.dart` runs every shared case
- [ ] `flutter analyze` clean

## Notes

- None.
