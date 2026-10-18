---
id: T6
title: "Migrate untyped tags once on store open with the legacy-as-topic fallback"
layer: "infra"
deps: ["T5"]
acs: ["AC-17", "AC-17b", "AC-18", "AC-31", "AC-32"]
files_hint: ["lib/core/services/collection_store.dart", "test/collection_tags_migration_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T6 — Migrate untyped tags once on store open with the legacy-as-topic fallback

## Why

Derives from [ADR-0003](../adr/0003-migrate-untyped-tags-once-on-store-open-and-empty-the-legacy-lists.md), [data-model §Migration](../data-model.md), sad §6 Flow 9.

## What

`_backfillTypedTags()` after `_backfillFiling()`, one writeTxn, oldest creation moment first, per data-model steps 1–4; log + retry on failure. A pure `effectiveTags(record)` helper reads legacy tags as topic tags while the typed lists are empty (sad §8 Legacy fallback).

## Definition of Done

- [ ] fixture test: AC-17, AC-17b, AC-31 Travel, AC-32 cross-collection spelling, source tags copied past 10, legacy emptied, times untouched, idempotent second open
- [ ] 500 seeded collections migrate within 1 s (spec §6)
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
