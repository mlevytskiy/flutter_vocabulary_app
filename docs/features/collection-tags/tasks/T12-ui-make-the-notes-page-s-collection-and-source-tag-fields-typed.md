---
id: T12
title: "Make the Notes page's collection and source tag fields typed, with focus-only suggestions and the copy-up snackbar"
layer: "ui"
deps: ["T7", "T8", "T9"]
acs: ["AC-15", "AC-16", "AC-29", "AC-34"]
files_hint: ["lib/features/notes/notes_screen.dart", "test/notes_typed_tags_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T12 — Make the Notes page's collection and source tag fields typed, with focus-only suggestions and the copy-up snackbar

## Why

Derives from screens SCR-08; sad §6 Flow 7.

## What

Replace the 'Collection tags' TagEditor and each source's TagEditor with two TypedTagFields (whenFocused). Collection fields → notifier.setCollectionTags(kind, …). Source fields → await notifier.updateSourceNote; refused kinds → SnackBar naming each kind once.

## Definition of Done

- [ ] widget tests: two fields per place, suggestions only when focused, snackbar text for a refused topic tag, existing Notes tests updated and green
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
