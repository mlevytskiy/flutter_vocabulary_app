---
id: T14
title: "Add the filter sheet: tag sections with counts, Created and Edited choices with a custom range, sort, Reset and Show N"
layer: "ui"
deps: ["T13"]
acs: ["AC-20", "AC-20b", "AC-21", "AC-37", "AC-38"]
files_hint: ["lib/features/collections/collections_filter_sheet.dart", "test/collections_filter_sheet_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T14 — Add the filter sheet: tag sections with counts, Created and Edited choices with a custom range, sort, Reset and Show N

## Why

Derives from screens SCR-06, SCR-07.

## What

`CollectionsFilterSheet` per SCR-06; custom range via showDateRangePicker with rangeProblem check; applies into CollectionsSearch only on Show N.

## Definition of Done

- [ ] widget tests: counts and Show all/narrow, live N incl. 0, Reset, dismiss without apply changes nothing, start-after-end refused
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
