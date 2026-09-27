---
id: T15
title: "Write the fixed definition column in the app AnkiDroid export"
layer: "app"
deps: ["T1", "T2", "T7"]
acs: ["AC-15"]
files_hint: ["lib/features/words_table/anki_export.dart", "lib/features/words_table/words_table_screen.dart", "test/anki_export_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T15 — Write the fixed definition column in the app AnkiDroid export

## Why

Derives from [ADR-0005](../adr/0005-export-anki-files-with-a-fixed-definition-column.md) and [spec AC-15](../spec.md).

## What

Same format as the README spec updated in T7: `#tags column:4`, `word \t translation \t definition \t tags`, the column the current mode hides left empty; `ankiField` escaping for the definition.

## Definition of Done

- [ ] Byte-level tests for each mode, including a definition with tabs, newlines and markup; output matches the README sample from T7.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Depends on T7 only for the agreed format text.
