---
id: T10
title: "Walk the warm-up plan in the Learn flow: save answers, react, pick topics, count"
layer: "app"
deps: ["T8", "T9"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-05", "AC-06", "AC-07", "AC-08", "AC-13", "AC-17"]
files_hint: ["lib/features/learn/flow/learn_flow_notifier.dart", "test/learn_flow_warm_up_test.dart"]
owner: "implementer agent"
estimate: "L"
status: "todo"
---

# T10 — Walk the warm-up plan in the Learn flow: save answers, react, pick topics, count

## Why

Derives from [AC-01](../spec.md), [AC-02](../spec.md), [AC-03](../spec.md), [AC-04](../spec.md), [AC-05](../spec.md), [AC-06](../spec.md), [AC-07](../spec.md), [AC-08](../spec.md), [AC-13](../spec.md), [AC-17](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] LearnFlow builds the plan at warm-up start, walks its steps, saves answers to the store before the reaction, starts the topic pick after the main answer, applies the counter rule when the cards open, sends finish and leave events, passes the chosen rule to the dialog setup
- [ ] at most 2 reactions + 1 topic pick
- [ ] notifier tests
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
