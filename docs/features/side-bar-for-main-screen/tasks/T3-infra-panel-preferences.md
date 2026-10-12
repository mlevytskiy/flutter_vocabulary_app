---
id: T3
title: "Keep the photo tab's height and the review-only design variant in preferences"
layer: "infra"
deps: []
acs: ["AC-01", "AC-14", "AC-19"]
files_hint: ["lib/core/providers.dart", "lib/core/providers.g.dart", "test/photo_panel_prefs_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T3 — Keep the photo tab's height and the review-only design variant in preferences

## Why

[spec AC-01, AC-14, AC-19](../spec.md), [sad §4 "The tab's height", "The design variant" and §8 Persistence](../sad.md), [ADR-0003](../adr/0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look.md).

## What

- `photoTabTopProvider`: keepAlive notifier like `wordDetailModeProvider`, key `photo_tab_top`, logical pixels from the top of the words page, with a `clamp(min, max)` helper used by the tab.
- `photoPanelVariantProvider`: keepAlive notifier, key `photo_panel_variant`, enum `PhotoPanelVariant { a, b, c }`, default `a`. Marked in a comment as removed at the pick (T20).

## Definition of Done

**Done when:** `photo_panel_prefs_test.dart` passes: `photo_tab_top` is read back after a restart, the first default sits beside the first word rows, a stored value is clamped between the top bar and the floating-button row, and a failed write of `photo_panel_variant` keeps the chosen variant in memory.

- [ ] test: round trip through `SharedPreferences.setMockInitialValues`
- [ ] test: no stored value gives the default
- [ ] test: clamp below the top bar and above the floating buttons
- [ ] test: variant write that throws keeps the in-memory value
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Shares `lib/core/providers.dart` with T4, so `implement` runs them in one lane.
- Not a domain model (CLAUDE.md rule 5): two preference values.
