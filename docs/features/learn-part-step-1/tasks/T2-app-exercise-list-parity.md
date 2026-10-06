---
id: T2
title: "Add the Exercise type and its const list to the app, pinned to the Worker's JSON"
layer: "domain"
deps: ["T1"]
acs: ["AC-04"]
files_hint: ["lib/features/learn/exercises.dart", "test/learn_exercises_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T2 — Add the Exercise type and its const list to the app, pinned to the Worker's JSON

## Why

[ADR-0003](../adr/0003-keep-the-exercise-list-as-json-in-the-worker-and-test-the-app-copy-against-it.md) and [sad §4](../sad.md) choice 3; quality goal QG-1 "One plan, two pages" ([sad §10](../sad.md)); spec §6 "Same plan on app and web".

## What

- `lib/features/learn/exercises.dart` — `class Exercise` (const constructor) and `const exercises = <Exercise>[…]` in plan order.
- `test/learn_exercises_test.dart` — `dart:io` + `dart:convert` read of the Worker JSON, entry-by-entry comparison.

## Definition of Done

**Done when:** `lib/features/learn/exercises.dart` defines `Exercise` (id, name, stage, available) and the const list of eleven, and `test/learn_exercises_test.dart` reads `vocab-photo-api/src/learn/exercises.json` from disk and passes only when all 11 entries match in id, name, stage, order and availability.

- [ ] the parity test passes; changing one name, stage, order or `available` on either side makes it fail (checked once by hand)
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- CLAUDE.md rule 5 override: `Exercise` was approved by the owner on 2026-10-06 ([sad §2](../sad.md)). It is the **only** new type allowed by this feature.
- Same precedent as `anki_export.dart` vs the Worker README format (sad §2 Conventions).
