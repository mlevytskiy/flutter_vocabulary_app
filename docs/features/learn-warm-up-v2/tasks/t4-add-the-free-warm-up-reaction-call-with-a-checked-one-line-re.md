---
id: T4
title: "Add the free warm-up reaction call with a checked one-line reply"
layer: "ports"
deps: []
acs: ["AC-05", "AC-12"]
files_hint: ["vocab-photo-api/src/learn/warm-up.ts", "vocab-photo-api/src/learn/routes.ts", "vocab-photo-api/test/learn-warm-up.test.mjs"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T4 — Add the free warm-up reaction call with a checked one-line reply

## Why

Derives from [AC-05](../spec.md), [AC-12](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] POST /learn/warm-up/reaction takes question + answer ≤ 80
- [ ] 1.8 s cutoff
- [ ] reply checked (one sentence, ≤ 15 words, no link, not echoing the answer) else empty
- [ ] never counted
- [ ] answer never logged
- [ ] Node tests green
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
