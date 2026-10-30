---
id: T8
title: "Let the talk mission take a topic, a reply limit and chosen words"
layer: "ports"
deps: []
acs: ["AC-13"]
files_hint: ["vocab-photo-api/src/learn/talk.ts", "vocab-photo-api/src/learn/talk-mixed.ts", "vocab-photo-api/test/talk-topic.test.ts"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T8 — Let the talk mission take a topic, a reply limit and chosen words

## Why

Derives from [AC-13](../spec.md); owner A4 and proxy Q1, Q7.

## What

Worker talk routes and tests.

## Definition of Done

- [ ] the mission route takes optional `topic {id?, text}`, `maxReplies` (6 or 12) and keeps the given words as the mission's words
- [ ] the reply route ends the talk at `maxReplies`; without the new fields behaviour is unchanged
- [ ] vitest cases
- [ ] deploy noted for the owner
- [ ] `flutter analyze` clean and `npx vitest run` green in `vocab-photo-api`

## Notes

—
