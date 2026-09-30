---
id: T8
title: "Add the subtitle import controls and the model picker to Settings"
layer: "ui"
deps: ["T6"]
acs: ["AC-05", "AC-05b", "AC-09", "AC-21"]
files_hint: ["lib/features/settings/settings_screen.dart", "test/settings_screen_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T8 — Add the subtitle import controls and the model picker to Settings

## Why

[ux-flows.md](../ux-flows.md) SCR-06; [sad §6 F2](../sad.md); [ADR-0004](../adr/0004-let-the-learner-pick-the-subtitle-model-from-a-worker-allow-list.md).

## What

- A "Subtitle import" group in `settings_screen.dart` built from the controls the screen already uses (look for the word detail mode control), with no new visual style (CLAUDE.md rule 3, override scoped in sad §11).

## Definition of Done

**Done when:** Widget tests show Settings (SCR-06) with purpose, level, maximum, the "Update with each import" switch and the four models, each change saved through the notifier; a maximum of 0 or 101 is not saved and shows "must be from 1 to 100"; the existing settings tests still pass.

- [ ] `flutter test test/settings_screen_test.dart test/settings_fab_alignment_test.dart`
- [ ] `flutter analyze`
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- No `screens.md` exists (the `screens` stage was skipped), so build to ux-flows SCR-06 and reuse the existing Settings controls.
