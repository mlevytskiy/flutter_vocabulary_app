---
id: T9
title: "Let story runs send each word's context, source and edited translation to the story writer"
layer: "ports"
deps: []
acs: ["AC-12"]
files_hint: ["vocab-photo-api/src/story/routes.ts", "vocab-photo-api/src/story/prompts.ts", "lib/core/services/story_api_service.dart", "vocab-photo-api/test/story-extras.test.ts"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T9 — Let story runs send each word's context, source and edited translation to the story writer

## Why

Derives from [AC-12](../spec.md); owner B11; data from [word-context](../../word-context/spec.md).

## What

Worker story route and prompt; the app service.

## Definition of Done

- [ ] story start takes optional `extras: [{word, context, source, translation}]`; the story writer prompt adds them as hints
- [ ] `StoryApiService` sends them when given
- [ ] vitest + a Dart service test
- [ ] `flutter analyze` clean and `npx vitest run` green in `vocab-photo-api`

## Notes

Fills the extras from word-context fields once word-context T2 is in; before that it sends empty extras.
