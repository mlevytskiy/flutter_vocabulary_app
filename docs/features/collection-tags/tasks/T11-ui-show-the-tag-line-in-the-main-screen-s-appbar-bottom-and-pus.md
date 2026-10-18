---
id: T11
title: "Show the tag line in the main screen's AppBar bottom and push filtered Collections on a tag tap"
layer: "ui"
deps: ["T9"]
acs: ["AC-13", "AC-14"]
files_hint: ["lib/features/word_input/collection_tag_line.dart", "lib/features/word_input/word_input_screen.dart", "lib/router/routes.dart", "test/collection_tag_line_test.dart"]
owner: "agent"
estimate: "S"
status: "todo"
---

# T11 — Show the tag line in the main screen's AppBar bottom and push filtered Collections on a tag tap

## Why

Derives from [ADR-0008](../adr/0008-carry-the-tag-tap-filter-in-typed-collectionsroute-query-fields-and-push-the-route.md); screens SCR-01.

## What

`CollectionTagLine` (PreferredSize, animated 0↔40 dp ~200 ms, horizontal ListView of TagChips, origin first). `CollectionsRoute` gains nullable typed `tagKind`, `tag`; regenerate routes.g.dart; chip tap → `CollectionsRoute(tagKind:, tag:).push(context)`.

## Definition of Done

- [ ] widget test at phone width: bottom height 0 with no tags, ≈40 dp with tags, origin chips before topic
- [ ] route test: tap pushes CollectionsRoute with kind + text
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
