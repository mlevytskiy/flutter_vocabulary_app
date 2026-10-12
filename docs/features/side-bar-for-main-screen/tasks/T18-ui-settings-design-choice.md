---
id: T18
title: "Add the temporary \"Photo panel design\" choice to Settings"
layer: "ui"
deps: ["T3"]
acs: ["AC-19"]
files_hint: ["lib/features/settings/settings_screen.dart", "test/settings_screen_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T18 — Add the temporary "Photo panel design" choice to Settings

## Why

[spec AC-19](../spec.md), [sad §4 "The design variant"](../sad.md), sad §6 Flow 10, ux-flows SCR-06.

## What

- One choice block copied from the word detail mode choice's pattern, marked in a comment as removed at the pick (T20).

## Definition of Done

**Done when:** `settings_screen_test.dart` passes the new case: the "Photo panel design" choice lists the variants, styled like the word detail mode choice, and picking one writes `photo_panel_variant` and changes `photoPanelVariantProvider` at once.

- [ ] test: tap a variant, read the provider and the mocked preferences
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Approved visible change (CLAUDE.md rule 3: "until the design pick, the Photo panel design choice in Settings").
