---
id: T3
title: "Add the pure name rule, the default date name and the creation moment from a collection id"
layer: "domain"
deps: []
acs: ["AC-02", "AC-03", "AC-04"]
files_hint: ["lib/core/models/collection_name.dart", "test/collection_name_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T3 — Add the pure name rule, the default date name and the creation moment from a collection id

## Why

[sad §5](../sad.md#5-building-block-view) `collection_name.dart`; [data-model.md](../data-model.md) `name` and the backfill; [api-sync-report](../contracts/api-sync-report.md) A (code points on both sides, shared test cases with the Worker).

## What

- `isValidCollectionName(String)` / a result naming why it failed; counts `runes`, not UTF-16 units.
- `defaultCollectionName(DateTime)` → `16.10.2026 14:30` in local time.
- `creationMomentOf(String collectionId)` → the base-36 microseconds before the `-`, or null.

## Definition of Done

**Done when:** Unit tests pass for `collection_name.dart`: the 1–60 code-point, one-line, not-only-spaces rule (empty, spaces, 60 and 61 code points, an emoji, a Cyrillic name, a pasted line break), the default name "dd.MM.yyyy HH:mm" in local time, and the creation moment parsed from a `WordCollection.create()` id, with null for an unparsable id.

- [ ] the rule's test cases are the same list T22 uses on the Worker (emoji, Cyrillic, 60, 61, line break, spaces)
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Pure Dart, no Isar import — starts in parallel with T2. If T2 has landed, use the new `WordCollection.create()` id format directly; it does not change in the rename.
