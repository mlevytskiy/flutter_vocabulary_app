---
id: T14
title: "Add the learner profile section to Learn settings"
layer: "ui"
deps: ["T1", "T7"]
acs: ["AC-11", "AC-04"]
files_hint: ["lib/features/learn/entry/learner_profile_section.dart", "lib/features/learn/entry/learn_settings_screen.dart", "test/learner_profile_section_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T14 — Add the learner profile section to Learn settings

## Why

Derives from [AC-11](../spec.md), [AC-04](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] section shows level, goal, daily context or Not set under "Used only to pick talk topics"
- [ ] change with the warm-up taps (goal/daily also own words ≤ 80)
- [ ] clear each
- [ ] widget tests
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
