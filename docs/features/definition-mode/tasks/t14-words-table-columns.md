---
id: T14
title: "Show words-table columns per mode with the filled rule"
layer: "ui"
deps: ["T1", "T2"]
acs: ["AC-12", "AC-14"]
files_hint: ["lib/features/words_table/words_table_screen.dart", "test/words_table_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T14 — Show words-table columns per mode with the filled rule

## Why

Derives from [spec AC-12, AC-14](../spec.md) and [sad §8 "Filled" row](../sad.md).

## What

Filter rows with `isFilled`; show word + translation, word + definition, or all three by mode, reusing the existing `DataTable`.

## Definition of Done

- [ ] Widget test: a definition-only row is listed in every mode; columns match each mode.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Shares `words_table_screen.dart` with T15/T16 — serialized.
