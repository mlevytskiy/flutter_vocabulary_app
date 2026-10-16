---
id: T8
title: "Route details, Notes tag edits and source notes through the store and adopt stored values in the main notifier"
layer: "app"
deps: ["T5"]
acs: ["AC-05", "AC-06", "AC-15", "AC-16", "AC-18", "AC-28", "AC-29", "AC-33"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "test/collection_tags_notifier_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T8 — Route details, Notes tag edits and source notes through the store and adopt stored values in the main notifier

## Why

Derives from ADR-0004 (callers), sad §8 Notifier adoption, sad §6 Flows 1, 4, 7.

## What

`saveDetails(...)` → `setDetails` then adopt description, typed tags, updatedAt, lastLocalModifiedAt. `setCollectionTags(kind, tags)` → same path (no debounce). `updateSourceNote` becomes `Future<Set<TagKind>>` (refused kinds) via `saveSourceNote`, adopting sources + typed tags + times. Leave rule uses keep (AC-28). Legacy fallback when reading tags.

## Definition of Done

- [ ] test: a Notes-page tag save shows in the notifier state at once and the next autosave doesn't write the older copy back (owner D4)
- [ ] test: a source tag survives the autosave (owner D11)
- [ ] test: edited time is not rolled back by markShared/updateDialogues after a details save
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
