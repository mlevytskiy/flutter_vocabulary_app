---
id: T7
title: "Write the fixed definition column in the Worker AnkiDroid file"
layer: "ports"
deps: ["T5"]
acs: ["AC-17", "AC-20"]
files_hint: ["vocab-photo-api/src/session/anki.ts", "vocab-photo-api/README.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T7 — Write the fixed definition column in the Worker AnkiDroid file

## Why

Derives from [ADR-0005](../adr/0005-export-anki-files-with-a-fixed-definition-column.md) and [spec AC-20](../spec.md).

## What

Header `#tags column:4`; records `word \t translation \t definition \t tags`, the column the document's `detail` hides left empty; missing `detail` → translation with an empty definition column. Update the format spec in `vocab-photo-api/README.md` (the single source both writers follow) including the one-time 3-field note type import steps.

## Definition of Done

- [ ] `npm run typecheck` clean.
- [ ] curl the page download for each mode: 4 columns, hidden column empty, tabs/newlines/markup escaped by `ankiField`.
- [ ] README format section matches the file byte for byte on a sample.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Must match T15 (app writer) exactly.
