---
id: T10
title: "Run the QG-1 stability suite: 100 interleavings of every background writer with every filing change"
layer: "tests"
deps: ["T7", "T9"]
acs: ["AC-27"]
files_hint: ["test/collection_stability_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T10 — Run the QG-1 stability suite: 100 interleavings of every background writer with every filing change

## Why

QG-1 in [sad §10](../sad.md#10-quality-requirements), spec §6 "Name and place stability", [AC-27](../spec.md#ac-27-us-06-us-07-us-09--cross-context).

## What

- A seeded random scheduler over fake writers that call the real store methods.
- Reopen the store at the end of each run and re-check.

## Definition of Done

**Done when:** `test/collection_stability_test.dart` runs 100 seeded runs that interleave each writer (autosave `put`, story, word groups, dialogue push, exam result, late lookup/import `update`) with rename, move, reorder, bin and erase on a real temp Isar, and asserts after each run and after reopening the store: 0 reverted names, places or orders, 0 collections back from the bin, 0 re-created erased collections.

- [ ] 100 runs green
- [ ] a deliberately broken `put()` (copying filing from the caller) makes the suite fail — checked once by hand, not committed
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Tagged so `tool/test.sh smoke` can skip it if it is slow; `changed` runs it.
