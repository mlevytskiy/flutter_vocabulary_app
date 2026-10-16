---
id: T6
title: "Backfill names, top-level order and keep for pre-feature collections when the store opens"
layer: "infra"
deps: ["T3", "T5"]
acs: ["AC-04"]
files_hint: ["lib/core/services/collection_store.dart", "test/collection_backfill_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T6 — Backfill names, top-level order and keep for pre-feature collections when the store opens

## Why

[data-model.md](../data-model.md) One-time backfill, [sad §6](../sad.md#6-runtime-view) F4 first-open branch, QG-2 ([sad §10](../sad.md#10-quality-requirements)).

## What

- Run beside `_fillRowIdsEverywhere` in `CollectionStore.open`, in one write transaction.
- Log `VOCAB: backfill named N (from id: a, fallback: b)`.
- A failed write is logged and retried on the next open; the store never throws.

## Definition of Done

**Done when:** A store test opens records with `name == null` and gets every one named from its id's creation moment (or the earliest of `updatedAt`, `lastLocalModifiedAt` and the sources' `takenAt` when the id cannot be parsed), at the top level, ordered oldest first, `keep = !isEmpty`, with words, sources, groups, dialogues, results and tags unchanged in count and content; a second open changes nothing.

- [ ] backfill test with parsable and unparsable ids
- [ ] idempotence: second open writes nothing
- [ ] the T2 fixture database, opened by this build, keeps its counts and gains names
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—

From T5 (2026-10-16): a pre-feature record reads `order` as Isar's null long (`-9223372036854775808`), not `0`, so the backfill must write `order` for every record it names, and must not take `order == 0` as "not yet backfilled" (use `name == null`).
