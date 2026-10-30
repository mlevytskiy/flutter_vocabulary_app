---
id: T12
title: "Add the warm-up view on the Talk screen: 2-step bar, topic and mode choices, own topic"
layer: "ui"
deps: ["T10"]
acs: ["AC-02", "AC-04"]
files_hint: ["lib/features/learn/flow/warm_up_view.dart", "lib/features/learn/talk/talk_widgets.dart", "test/learn_warm_up_view_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T12 — Add the warm-up view on the Talk screen: 2-step bar, topic and mode choices, own topic

## Why

Derives from [AC-02](../spec.md), [AC-04](../spec.md); owner A2/A16/A19/A20, proxy Q11.

## What

One view file plus small hooks in talk widgets.

## Definition of Done

- [ ] reuses the talk's bubbles and answer choices (`talk_widgets.dart`) and its mic for the own topic
- [ ] the bar has 2 steps; no Skip; the gear opens `LearnSettingsRoute`
- [ ] answers go to `LearnFlowNotifier`
- [ ] widget tests
- [ ] `flutter analyze` clean

## Notes

—
