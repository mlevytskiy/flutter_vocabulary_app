---
id: T3
title: "Add the three-way word detail mode to Settings"
layer: "ui"
deps: ["T2"]
acs: ["AC-01"]
files_hint: ["lib/features/settings/settings_screen.dart", "test/settings_screen_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T3 — Add the three-way word detail mode to Settings

## Why

Derives from [spec US-01, AC-01](../spec.md) and [sad §5](../sad.md).

## What

Under the existing drag-and-drop `SwitchListTile`, a titled group of three `RadioListTile`s — Translation, Definition, Translation + definition — bound to the T2 provider. Reuses the screen's existing `ListView` and Material list tiles; no new component.

## Definition of Done

- [ ] Widget test: three options shown, Translation selected on a fresh install; tapping Definition updates the provider.
- [ ] The drag-and-drop row is unchanged.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
