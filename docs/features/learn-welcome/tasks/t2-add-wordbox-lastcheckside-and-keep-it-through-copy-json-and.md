---
id: T2
title: "Add WordBox.lastCheckSide and keep it through copy, JSON and the store"
layer: "infra"
deps: ["T1"]
acs: ["AC-07"]
files_hint: ["lib/core/models/word_box.dart", "test/word_box_store_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T2 — Add WordBox.lastCheckSide and keep it through copy, JSON and the store

## Why

Derives from [AC-07](../spec.md); moved here from [self-check-cards T10](../../self-check-cards/tasks.json) ([ADR-0006](../adr/0006-one-self-check-card-and-one-set-of-rating-rules.md)).

## What

Model field, generated code, store test.

## Definition of Done

- [ ] `WordBox.lastCheckSide` (`''`, `uk`, `en`) with copy and JSON
- [ ] store test: `put` keeps the stored side, `update` changes it
- [ ] `flutter analyze` clean

## Notes

—
