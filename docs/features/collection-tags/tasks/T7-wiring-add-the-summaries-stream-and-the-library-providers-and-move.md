---
id: T7
title: "Add the summaries stream and the library providers, and move tag suggestions into features/tags"
layer: "wiring"
deps: ["T3", "T6"]
acs: ["AC-08", "AC-27", "AC-30", "AC-35", "AC-38"]
files_hint: ["lib/core/services/collection_store.dart", "lib/core/providers.dart", "lib/features/tags/tag_suggestions.dart", "lib/features/notes/tag_suggestions.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T7 — Add the summaries stream and the library providers, and move tag suggestions into features/tags

## Why

Derives from ADR-0006, ADR-0009, sad §5.

## What

`watchSummaries()` (all non-binned collections incl. empty, folder path + tree index, trailing 300 ms debounce). Providers `collectionSummaries`, `tagLibrary` in core/providers.dart. Cut-and-paste `notes/tag_suggestions.dart` to `features/tags/` and replace its pools with `tagSuggestions(kind)` built on T2's ranking + T3's useCounts.

## Definition of Done

- [ ] stream test: empty collections included, binned excluded, one re-read per write burst
- [ ] provider test: ranking per AC-35, forgotten excluded
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
