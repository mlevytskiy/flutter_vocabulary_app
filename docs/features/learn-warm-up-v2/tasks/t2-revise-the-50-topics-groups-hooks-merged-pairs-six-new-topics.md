---
id: T2
title: "Revise the 50 topics: groups, hooks, merged pairs, six new topics and permanent aliases"
layer: "ports"
deps: []
acs: ["AC-14", "AC-15"]
files_hint: ["vocab-photo-api/src/learn/topics.ts", "vocab-photo-api/test/learn-topics.test.mjs"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T2 — Revise the 50 topics: groups, hooks, merged pairs, six new topics and permanent aliases

## Why

Derives from [AC-14](../spec.md), [AC-15](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] topics.ts has 50 unique ids in 8 groups with a hook each
- [ ] the 6 merged ids resolve through an alias map pinned by a test
- [ ] the first three ids unchanged
- [ ] keywords updated for merged topics
- [ ] Node tests green
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
