---
id: T11
title: "Draw the warm-up as a dialog: step bar, level, main and grammar taps, own words, topics with situations"
layer: "ui"
deps: ["T1", "T10"]
acs: ["AC-01", "AC-03", "AC-04", "AC-06", "AC-07", "AC-13"]
files_hint: ["lib/features/learn/flow/warm_up_view.dart", "test/warm_up_view_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T11 — Draw the warm-up as a dialog: step bar, level, main and grammar taps, own words, topics with situations

## Why

Derives from [AC-01](../spec.md), [AC-03](../spec.md), [AC-04](../spec.md), [AC-06](../spec.md), [AC-07](../spec.md), [AC-13](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] warm_up_view shows the 3–4 step bar, gear, AI bubbles with reactions, tap answers per step, the Something else composer (80-char rule, typed and spoken), topic tiles with situation lines and My own topic…, Hard/Easy
- [ ] no Skip
- [ ] widget tests
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
