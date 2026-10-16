---
id: T16
title: "Update architecture.md and the roadmap for collection-tags"
layer: "docs"
deps: ["T10", "T11", "T12", "T13", "T14", "T15"]
acs: []
files_hint: ["docs/architecture.md", "docs/roadmap.md"]
owner: "agent"
estimate: "S"
status: "todo"
---

# T16 — Update architecture.md and the roadmap for collection-tags

## Why

Derives from sad §5.

## What

Add the new files (tag_rules, collection_search, tag_library_entry, features/tags, details sheet, filter sheet, tag line) to architecture.md; roadmap step 25 → code complete.

## Definition of Done

- [ ] docs list every new file; roadmap status updated
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
