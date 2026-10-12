---
id: T12
title: "Give the word list a ScrollController, row keys, a row highlight and the jump to a row"
layer: "ui"
deps: []
acs: ["AC-04", "AC-06"]
files_hint: ["lib/features/word_input/widgets/word_row_item.dart", "lib/features/word_input/photo_panel/row_jump.dart", "lib/features/word_input/word_input_screen.dart", "test/row_jump_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T12 — Give the word list a ScrollController, row keys, a row highlight and the jump to a row

## Why

[spec AC-04, AC-06](../spec.md), [sad §4 "Jump to a photo's rows" and "Highlight"](../sad.md), sad §6 Flow 1 and Flow 4, QG-2c.

## What

- `WordRowItem` gets an optional `highlight` (a `Decoration?`); `null` draws exactly today's row.
- `word_input_screen.dart`: one `ScrollController` and one `GlobalKey` per row for both `ListView.builder` and `ReorderableListView.builder`, kept in step with the screen's per-row lists.
- `row_jump.dart`: jump to an estimated offset (index × average height of the rows built so far), then `Scrollable.ensureVisible` on the row's key with minimum movement, repeated for a bounded number of frames until it is built and in view.

## Definition of Done

**Done when:** `row_jump_test.dart` passes with 200 rows of mixed heights: after the jump and `pump(500 ms)` the first linked row (in the list's current order) is fully in view, an already visible row does not move, both the normal and the drag-mode list scroll; `word_row_layout_test.dart` and `app_smoke_test.dart` stay green unchanged with no highlight.

- [ ] test: 200 mixed-height rows, target near the end; target already visible; drag mode on
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Starts in parallel with the panel lane: it touches no `photo_panel.dart`.
- CLAUDE.md rule 3: no visible change while no photo is selected.
