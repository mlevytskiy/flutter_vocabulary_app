---
id: T15
title: "Pin that description and tags never reach a publish payload or an export file"
layer: "tests"
deps: ["T4"]
acs: ["AC-26"]
files_hint: ["test/collection_tags_privacy_test.dart"]
owner: "agent"
estimate: "S"
status: "todo"
---

# T15 — Pin that description and tags never reach a publish payload or an export file

## Why

Derives from spec AC-26, sad §8 Privacy.

## What

Build a collection with description + typed tags (+ source tags); assert the publish request body (collection_publish_service) and every share format output contain neither.

## Definition of Done

- [ ] test passes and fails if either field is added to a payload
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
