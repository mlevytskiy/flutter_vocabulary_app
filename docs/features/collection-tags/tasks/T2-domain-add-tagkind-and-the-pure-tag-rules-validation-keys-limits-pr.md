---
id: T2
title: "Add TagKind and the pure tag rules: validation, keys, limits, presets, legacy sort, matching and ranking"
layer: "domain"
deps: []
acs: ["AC-04", "AC-09", "AC-10", "AC-11", "AC-17b", "AC-31", "AC-35"]
files_hint: ["lib/core/models/tag_kind.dart", "lib/core/services/tag_rules.dart", "test/tag_rules_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T2 — Add TagKind and the pure tag rules: validation, keys, limits, presets, legacy sort, matching and ranking

## Why

Derives from [sad §5/§8](../sad.md) Tag identity and Tag limits; [ADR-0001](../adr/0001-store-typed-tags-as-separate-origin-and-topic-lists-beside-the-legacy-list.md), [ADR-0003](../adr/0003-migrate-untyped-tags-once-on-store-open-and-empty-the-legacy-lists.md).

## What

`enum TagKind { origin, topic }` (ordinal order fixed). `tag_rules.dart` (pure Dart, no Flutter): `tagProblem(text)` (1–30, one line, trimmed), `tagKey`, `canAddTag(list)` (<10), `addTag(list, text, knownSpellings)` (case-insensitive dedupe, existing spelling wins), `originPresets`/`topicPresets` (the exact ordered lists of AC-31), `sortLegacyTags(list) → (origin, topic)`, `mergeCaseDuplicates`, `matchesWordStart(text, query)`, `rankSuggestions(kind, library entries, counts, presets, added, query)` per AC-35 (in use by count then lastUsedAt, then unused library, then presets; forgotten and already-added excluded; max N).

## Definition of Done

- [ ] unit tests cover every rule, incl. AC-31 preset lists and 'Travel'→origin, word-start 'co' matches Cooking/Home cooking not Tacos
- [ ] autocomplete ranking over 1,000 entries completes ≤ 50 ms in a timed unit test (spec §6)
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
