---
id: T11
title: "Lay out word rows per word detail mode"
layer: "ui"
deps: ["T2", "T10"]
acs: ["AC-02", "AC-03", "AC-04", "AC-11"]
files_hint: ["lib/features/word_input/widgets/word_row_item.dart", "lib/features/word_input/word_input_screen.dart", "test/word_row_layout_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T11 — Lay out word rows per word detail mode

## Why

Derives from [spec US-02, AC-02..AC-04](../spec.md) and [sad §2 rule-3 override](../sad.md).

## What

Translation mode: the existing `SyncedTextFieldRow` branch untouched. Definition mode: Word full width, Definition full width underneath (multi-line), no Translation field, no translation dots, no Word lightning; pronunciation flags at the full-width Word field's right edge. Both: today's row plus the full-width Definition field underneath. Reuses `TextField` styling from `SyncedTextFieldRow` and the card decoration already in `WordRowItem`.

## Definition of Done

- [ ] Widget tests: each mode builds the expected fields and hides the others.
- [ ] Screenshot comparison on one device: translation mode identical before/after (AC-02).
- [ ] Switching modes on a 30-row session changes layout only; all texts intact (AC-11).
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Rule 3 override is scoped: never rewrite the translation branch.
