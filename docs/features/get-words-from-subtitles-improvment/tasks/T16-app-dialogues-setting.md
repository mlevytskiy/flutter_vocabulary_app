---
id: T16
title: "Add the \"Get dialogues from subtitles\" switch to Settings"
layer: "ui"
deps: []
acs: ["AC-01", "AC-23"]
files_hint: ["lib/core/providers.dart", "lib/features/settings/settings_screen.dart", "test/settings_screen_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T16 — Add the "Get dialogues from subtitles" switch to Settings

## Why

[sad §4](../sad.md) "Mobile UI architecture", ux-flows SCR-03.

## What

- A persisted `dialoguesSettingProvider` in `shared_preferences`, off by default, like `wordDetailModeProvider`.
- One switch row "Get dialogues from subtitles" on the existing Settings screen, built with the screen's existing switch row. No confirmation.

## Definition of Done

**Done when:** The switch shows off on first launch, keeps its value across restarts, and the provider reflects it.

- [ ] widget test: default off, toggle, restart keeps the value
- [ ] `settings_screen_test.dart` green, `flutter analyze` clean

## Notes

- Reuses the Settings screen's existing switch row; no new component.
