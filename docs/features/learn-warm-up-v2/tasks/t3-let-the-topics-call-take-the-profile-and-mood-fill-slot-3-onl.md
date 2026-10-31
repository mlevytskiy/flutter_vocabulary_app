---
id: T3
title: "Let the topics call take the profile and mood, fill slot 3 only from the profile, and write situation lines"
layer: "ports"
deps: ["T2"]
acs: ["AC-13", "AC-12"]
files_hint: ["vocab-photo-api/src/learn/topics.ts", "vocab-photo-api/test/learn-topics.test.mjs"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T3 — Let the topics call take the profile and mood, fill slot 3 only from the profile, and write situation lines

## Why

Derives from [AC-13](../spec.md), [AC-12](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] optional profile (each field ≤ 80) and mood accepted, bad fields rejected
- [ ] the model returns word ids, ≤ 1 profile id and lines
- [ ] code builds [word1, word2, profile-or-word3]
- [ ] each line ≤ 20 words and checked, else the hook
- [ ] no profile text logged
- [ ] Node tests green
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
