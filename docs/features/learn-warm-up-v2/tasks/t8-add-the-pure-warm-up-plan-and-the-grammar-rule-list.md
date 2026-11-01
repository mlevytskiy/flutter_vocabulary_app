---
id: T8
title: "Add the pure warm-up plan and the grammar rule list"
layer: "domain"
deps: ["T7"]
acs: ["AC-01", "AC-02", "AC-03", "AC-06", "AC-07", "AC-08"]
files_hint: ["lib/features/learn/flow/warm_up_plan.dart", "lib/features/learn/flow/grammar_rules.dart", "test/warm_up_plan_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T8 — Add the pure warm-up plan and the grammar rule list

## Why

Derives from [AC-01](../spec.md), [AC-02](../spec.md), [AC-03](../spec.md), [AC-06](../spec.md), [AC-07](../spec.md), [AC-08](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] planWarmUp gives intro only without a level, the next main question from a random round, grammar when counter ≥ 4 and level set and no intro and talk limit not reached
- [ ] 3 or 4 steps
- [ ] grammar_rules.dart has the 15 rules, 4 picked at random per level, Beginner → Elementary, Not sure → Elementary + Intermediate
- [ ] counter rule (+1, or 0 after an answered grammar question) as a pure function
- [ ] unit tests with seeded random
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
