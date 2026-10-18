---
id: T13
title: "Add search mode and the flat results view to the Collections screen, seeded from the route"
layer: "ui"
deps: ["T7", "T9", "T11"]
acs: ["AC-14", "AC-19", "AC-22", "AC-23", "AC-24", "AC-27", "AC-39"]
files_hint: ["lib/features/collections/collections_search_notifier.dart", "lib/features/collections/collections_results_view.dart", "lib/features/collections/collections_screen.dart", "test/collections_search_test.dart"]
owner: "agent"
estimate: "L"
status: "todo"
---

# T13 — Add search mode and the flat results view to the Collections screen, seeded from the route

## Why

Derives from screens SCR-04, SCR-05; ux-flows US-05, US-07 + 'States worth naming'.

## What

`@riverpod CollectionsSearch` (query, filter, entered-from-tag flag) seeded from CollectionsRoute fields; AppBar search field + filter icon; results list of CollectionResultTile (name, folder path, tag chips); filter chips row with Clear; empty state; drag/reorder/delete mode disabled while active; Back: from SCR-04 clears first, from a tag pops; tap result opens it as current.

## Definition of Done

- [ ] widget tests for AC-19, AC-22, AC-24, AC-39 (all three Back/Clear/tap paths) and a route-seeded tag filter
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
