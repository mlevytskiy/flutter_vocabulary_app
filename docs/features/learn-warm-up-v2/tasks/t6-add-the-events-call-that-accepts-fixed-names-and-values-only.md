---
id: T6
title: "Add the events call that accepts fixed names and values only"
layer: "ports"
deps: []
acs: ["AC-17"]
files_hint: ["vocab-photo-api/src/learn/events.ts", "vocab-photo-api/src/learn/routes.ts", "vocab-photo-api/test/learn-events.test.mjs"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T6 — Add the events call that accepts fixed names and values only

## Why

Derives from [AC-17](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] POST /learn/events takes ≤ 20 events from a fixed list with fixed values and numbers
- [ ] any free string or unknown name rejected
- [ ] each event logged with logEvent
- [ ] Node tests green
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
