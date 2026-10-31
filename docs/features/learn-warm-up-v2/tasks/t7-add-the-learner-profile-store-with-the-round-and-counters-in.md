---
id: T7
title: "Add the learner profile store with the round and counters in one preferences value"
layer: "infra"
deps: []
acs: ["AC-04", "AC-11", "AC-03"]
files_hint: ["lib/core/services/learner_profile_store.dart", "lib/core/providers.dart", "test/learner_profile_store_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T7 — Add the learner profile store with the round and counters in one preferences value

## Why

Derives from [AC-04](../spec.md), [AC-11](../spec.md), [AC-03](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] LearnerProfileStore reads/writes one versioned JSON value (level, goal, daily, round, grammar counter, talks-to-thumbs counter)
- [ ] bad value reads as empty
- [ ] 1–2 char answers saved only into empty fields
- [ ] clearing a field keeps round and counters
- [ ] provider in providers.dart
- [ ] unit tests
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
