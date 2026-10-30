---
id: T6
title: "Add the 50 topics and POST /learn/topics to the Worker"
layer: "ports"
deps: []
acs: ["AC-03"]
files_hint: ["vocab-photo-api/src/learn/topics.ts", "vocab-photo-api/src/learn/routes.ts", "vocab-photo-api/test/learn-topics.test.ts"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T6 — Add the 50 topics and POST /learn/topics to the Worker

## Why

Derives from [AC-03](../spec.md); see [ADR-0003](../adr/0003-keep-fifty-topics-in-the-worker-and-pick-three-with-ai.md).

## What

New Worker file, route, tests.

## Definition of Done

- [ ] `src/learn/topics.ts`: 50 `{id, title ≤ 4 words, description, keywords 5–10}` written once (proxy Q5)
- [ ] `POST /learn/topics {words}` asks the talk mission's model for 3 ids; invalid or missing ids filled from a keyword overlap score; no talk counter change
- [ ] vitest cases incl. a model failure
- [ ] deploy noted for the owner (not run by the task)
- [ ] `flutter analyze` clean and `npx vitest run` green in `vocab-photo-api`

## Notes

—
