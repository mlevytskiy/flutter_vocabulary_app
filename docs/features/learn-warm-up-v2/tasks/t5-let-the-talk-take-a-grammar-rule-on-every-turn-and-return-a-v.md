---
id: T5
title: "Let the talk take a grammar rule on every turn and return a verdict per reply"
layer: "ports"
deps: []
acs: ["AC-09", "AC-10"]
files_hint: ["vocab-photo-api/src/learn/talk.ts", "vocab-photo-api/src/learn/talk-mixed.ts", "vocab-photo-api/test/learn-talk-mixed.test.mjs"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T5 — Let the talk take a grammar rule on every turn and return a verdict per reply

## Why

Derives from [AC-09](../spec.md), [AC-10](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] grammar ≤ 40 chars accepted on start and reply
- [ ] prompts invite the rule, keep the target-word rule, and add the gentle fix only after a wrong line
- [ ] every reply with a rule returns grammarVerdict right/wrong/unsure
- [ ] old callers unchanged
- [ ] Node tests green
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
