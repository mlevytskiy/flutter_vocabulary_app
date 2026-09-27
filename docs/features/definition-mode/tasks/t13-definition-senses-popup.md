---
id: T13
title: "Pick a sense from the definition dots popup"
layer: "ui"
deps: ["T8", "T11"]
acs: ["AC-08"]
files_hint: ["lib/features/word_input/widgets/definition_dots_button.dart", "lib/features/word_input/widgets/definition_options_content.dart", "lib/features/word_input/widgets/word_row_item.dart", "lib/features/word_input/word_input_screen.dart", "test/definition_senses_popup_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T13 — Pick a sense from the definition dots popup

## Why

Derives from [spec US-04, AC-08](../spec.md) and [ADR-0003](../adr/0003-store-definition-text-and-senses-on-the-word-row.md).

## What

A dots button beside the Definition field built like `TranslationDotsButton` (popup_menu_2, same controller and close handling): solid when senses are stored, outlined otherwise; opening with no stored senses calls the dictionary; the list shows every short sense; tapping one replaces the definition. Reuses the translation popup's chip/list styling.

## Definition of Done

- [ ] Widget tests: stored senses open without a lookup; tapping a sense replaces the text; with no senses, opening triggers one lookup and shows the result.
- [ ] Existing dots close-race tests still pass.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

New widgets justified: no existing definition picker; they mirror the translation pair.
