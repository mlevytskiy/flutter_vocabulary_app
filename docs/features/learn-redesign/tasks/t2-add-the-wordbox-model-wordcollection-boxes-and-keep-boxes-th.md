---
id: T2
layer: infra
deps: ["T1"]
acs: ["AC-15"]
estimate: M
owner: "implementer agent"
status: todo
---

# T2 — Add the WordBox model, WordCollection.boxes and keep boxes through CollectionStore.put

**Derives from:** [spec](../spec.md) AC-15 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

build_runner regenerates; JSON round-trip test for boxes; store test: put() of a stale copy keeps stored boxes, update() can change them, a binned+restored collection keeps them

## Files

- `lib/core/models/word_box.dart`
- `lib/core/models/word_collection.dart`
- `lib/core/services/collection_store.dart`
- `test/word_box_store_test.dart`
