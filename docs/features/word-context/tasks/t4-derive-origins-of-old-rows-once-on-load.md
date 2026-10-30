---
id: T4
title: "Derive origins of old rows once on load"
layer: "infra"
deps: ["T3"]
acs: ["AC-03"]
files_hint: ["lib/core/services/collection_store.dart", "test/word_origin_store_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T4 — Derive origins of old rows once on load

## Why

Derives from [AC-03](../spec.md); owner B3.

## What

A one-time pass in the store.

## Definition of Done

- [ ] `CollectionStore` fills a missing origin with `originForRow` the first time a collection is read after the update, in one write
- [ ] test: mixed old rows → right types; flags false; second load is a no-op
- [ ] `flutter analyze` clean

## Notes

—
