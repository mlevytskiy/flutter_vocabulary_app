---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0007 — Build the typed tag field on built-in chips and RawAutocomplete without a package

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

The owner asked for a nice-looking tag component and to research libraries (spec §1, owner brief). The repo already has `TagEditor` (`lib/features/notes/tag_editor.dart`: chips plus a field with filtered suggestions). CLAUDE.md rule 5 forbids new packages without owner approval.

## Decision drivers

- Rule 5: no new packages unless approved. The owner proxy reviewed the options and declined them (batch 1, Q3j).
- Package health from the owner's review: textfield_tags' last release was March 2024, chips_input was last updated in 2022, and flutter_tags_x was last released in June 2022. tagged_field scores 45/100 on health. For choose_input_chips the owner found no release date or activity data.
- Needed behaviour that packages don't provide out of the box: two kinds with icons and tints, a suggestion row ranked from the library and presets, long-press Forget, and limit messages under the field.

## Considered options

1. **Grow `TagEditor` into `TypedTagField`** on Flutter's `InputChip`, `ActionChip` and `RawAutocomplete`, in a new `lib/features/tags/` folder. `tag_suggestions.dart` moves there by cut-and-paste.
2. **Adopt a chips-input package** (textfield_tags or choose_input_chips) and style it.

## Decision outcome

**Chosen:** option 1. There is no dependency risk, it reuses tested code, and the look comes from one `TagChip` widget (icon + tint per kind) used everywhere: sheet, Notes, tag line and filter. Option 2 adds an unmaintained or unproven dependency and still needs all the custom behaviour on top.

## Consequences

**Positive**
- No new package, and one chip look across four places.

**Negative**
- We own the autocomplete overlay's edge cases (keyboard, scrolling).

**Neutral**
- A package could still replace the field's internals later behind the same widget API.

## Links

- Spec: [[../spec.md]] AC-07, AC-12, AC-34, AC-35
- SAD: [[../sad.md]] §4, §5
