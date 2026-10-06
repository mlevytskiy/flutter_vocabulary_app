---
id: T5
title: "Remove the Screenshot item, its capture code and the screenshot package"
layer: "wiring"
deps: []
acs: ["AC-01"]
files_hint: ["lib/features/word_input/widgets/word_input_speed_dial.dart", "lib/features/word_input/word_input_screen.dart", "pubspec.yaml", "pubspec.lock", "CLAUDE.md", "docs/architecture.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T5 — Remove the Screenshot item, its capture code and the screenshot package

## Why

spec §1 decision (Screenshot removed, rule 3 updated), AC-01; [sad §2](../sad.md) overrides; [sad §11](../sad.md) repo-text row.

## What

- Drop the Screenshot `SpeedDialChild` and the `onScreenshot` parameter; remove the controller, wrapper, `_takeScreenshot` and its imports from `word_input_screen.dart`.
- `flutter pub remove screenshot`.
- Update the two rule texts in the same commit.

## Definition of Done

**Done when:** The red + menu no longer has Screenshot, `_takeScreenshot` and the `Screenshot` wrapper are gone, `screenshot` is removed from `pubspec.yaml`, CLAUDE.md rule 3 and `docs/architecture.md` rule 4 no longer list it, and `flutter analyze` + `flutter test` pass.

- [ ] `grep -rn screenshot lib pubspec.yaml` finds nothing
- [ ] `flutter analyze` and `flutter test` clean

## Notes

- **The working tree already has an uncommitted owner change in `word_input_speed_dial.dart`** (the subtitles icon) — commit or keep it before this task edits the file.
- The green "Import from Quizlet" item is added in T13, where its flow exists.
