---
id: T13
title: "Show the grammar line and the occasional 👍/👎 on the results page"
layer: "ui"
deps: ["T1", "T9", "T12"]
acs: ["AC-10", "AC-16", "AC-17"]
files_hint: ["lib/features/learn/flow/flow_result.dart", "test/learn_flow_results_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T13 — Show the grammar line and the occasional 👍/👎 on the results page

## Why

Derives from [AC-10](../spec.md), [AC-16](../spec.md), [AC-17](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] results Talk part shows "Rule: used N times, M right" only when something was judged
- [ ] 👍/👎 on every 3rd talk reaching results (finished or ended), one tap records an event and hides it
- [ ] the counter lives in the store
- [ ] widget tests
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
