---
id: T16
title: "Show the flow's results: cards, stories, talk, due tomorrow, three buttons"
layer: "ui"
deps: ["T10"]
acs: ["AC-15"]
files_hint: ["lib/features/learn/session/session_results_screen.dart", "lib/features/learn/flow/flow_result.dart", "test/learn_flow_results_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T16 — Show the flow's results: cards, stories, talk, due tomorrow, three buttons

## Why

Derives from [AC-15](../spec.md); owner A13, proxy Q10.

## What

Results screen and a flow result type.

## Definition of Done

- [ ] `session_results_screen.dart` takes a flow result and shows the three parts with the existing layout
- [ ] Exercises opens a learning session on the card words; Talk with AI opens a talk; Done goes back
- [ ] widget tests
- [ ] `flutter analyze` clean

## Notes

—
