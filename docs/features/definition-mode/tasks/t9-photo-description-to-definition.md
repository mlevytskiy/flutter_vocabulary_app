---
id: T9
title: "Store photo descriptions as definitions"
layer: "app"
deps: ["T1"]
acs: ["AC-09", "AC-10"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "test/photo_words_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T9 — Store photo descriptions as definitions

## Why

Derives from [spec AC-09, AC-10](../spec.md) and [ADR-0003](../adr/0003-store-definition-text-and-senses-on-the-word-row.md).

## What

In the photo path, each `VocabWord.description` goes into the row's definition in every mode; the translation gets only `VocabWord.translation` (drop the `translation ?? description` fallback). No dictionary lookups on this path.

## Definition of Done

- [ ] Test: a photo result with translation + description fills both; one with description only leaves translation empty and fills the definition (AC-10).
- [ ] Test or log check: the dictionary service is never called during photo import (AC-09).
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Shares `word_input_screen.dart` with T10–T13 — serialized.
