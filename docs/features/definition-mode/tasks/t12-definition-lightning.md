---
id: T12
title: "Fill a definition from the lightning icon"
layer: "ui"
deps: ["T8", "T11"]
acs: ["AC-05", "AC-06", "AC-07"]
files_hint: ["lib/features/word_input/widgets/word_row_item.dart", "lib/features/word_input/word_input_screen.dart", "lib/features/word_input/lightning_rules.dart", "docs/lightning_icon_rules.md", "test/definition_lightning_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T12 — Fill a definition from the lightning icon

## Why

Derives from [spec US-03, AC-05..AC-07](../spec.md) and [sad §6 flow 1](../sad.md).

## What

A purple `Icons.electric_bolt` overlaid on the Definition field, same focus gate (Rule 0) and spinner as the Translation icon. On tap: `DictionaryService.define`; senses → fill the first sense and store all senses; not found → snackbar "No definition found — did you mean: …", field untouched; unavailable → snackbar "Definitions are temporarily unavailable", field untouched. Document the Definition icon rule in `docs/lightning_icon_rules.md`.

## Definition of Done

- [ ] Widget tests with a fake service: fills first sense; not-found leaves the field empty and shows suggestions; unavailable leaves the field unchanged and translation icons still work.
- [ ] Timing log line around the lookup is emitted (for spec §6 p95 checks).
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
