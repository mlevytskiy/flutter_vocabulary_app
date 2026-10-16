---
id: T9
title: "Add TagChip and grow TagEditor into TypedTagField with hints, examples, suggestion row, autocomplete, limits and Forget"
layer: "ui"
deps: ["T2"]
acs: ["AC-04", "AC-07", "AC-08", "AC-09", "AC-10", "AC-11", "AC-12", "AC-35"]
files_hint: ["lib/features/tags/tag_chip.dart", "lib/features/tags/typed_tag_field.dart", "lib/features/notes/tag_editor.dart", "test/typed_tag_field_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T9 — Add TagChip and grow TagEditor into TypedTagField with hints, examples, suggestion row, autocomplete, limits and Forget

## Why

Derives from [ADR-0007](../adr/0007-build-the-typed-tag-field-on-built-in-chips-and-rawautocomplete-without-a-package.md); [screens](../screens.md) SCR-02 tag states, SCR-09, §New components.

## What

`TagChip(kind, text, onDeleted?, onTap?)` (origin: explore_outlined + secondaryContainer; topic: tag + tertiaryContainer). `TypedTagField(kind, tags, suggestions, onChanged, onForget, showSuggestions: always|whenFocused)`: hint, helper line, ≤8 suggestion ActionChips, RawAutocomplete options, errorText for tag problems/limit, long-press menu 'Forget this tag' (not for presets). Suggestions come in as a parameter (no provider dependency).

## Definition of Done

- [ ] widget tests: hint + helper text per kind, tap suggestion adds and removes it from the row, 11th tag refused with message, long-press Forget only on own tags, whenFocused mode hides the row unfocused
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
