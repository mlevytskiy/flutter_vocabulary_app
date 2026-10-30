---
id: T5
title: "Add the pure story slot scheduler"
layer: "domain"
deps: ["T1"]
acs: ["AC-10"]
files_hint: ["lib/features/learn/flow/story_slots.dart", "test/learn_story_slots_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T5 — Add the pure story slot scheduler

## Why

Derives from [AC-10](../spec.md); the placement rule (owner, 2026-10-30; A9 = 5, A17, proxy Q8).

## What

One pure file and its tests.

## Definition of Done

- [ ] `StorySlots` takes the group ends and answers, after each card or skip, the next page: card, story n, or wait n
- [ ] the 5-extra-card limit is a parameter (default 5)
- [ ] tests in `test/learn_story_slots_test.dart`
- [ ] `flutter analyze` clean

## Notes

—
