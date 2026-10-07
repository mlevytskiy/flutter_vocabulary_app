---
id: T5
title: "Run scene pictures as two-step runs of the story run workflow"
layer: "app"
deps: ["T1"]
acs: ["AC-14", "AC-18", "AC-19", "AC-22"]
files_hint: ["vocab-photo-api/src/story/run-steps.ts", "vocab-photo-api/src/story/workflow.ts", "vocab-photo-api/src/story/prompts.ts", "vocab-photo-api/src/story/routes.ts", "vocab-photo-api/src/story/store.ts", "vocab-photo-api/test/story-scene.test.mjs"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T5 — Run scene pictures as two-step runs of the story run workflow

## Why

[sad §4](../sad.md) choice 4, [ADR-0004](../adr/0004-draw-scene-pictures-as-two-step-runs-of-the-story-run-workflow.md), [sad §6](../sad.md) critical flow 2, [sad §8](../sad.md) Spending control and Prompt injection.

## What

- `POST /story/runs` accepts `kind: "scene"` with `sceneText` (the dialogue lines), a prompt model and a picture model. It takes no story model. The models are checked against the offered list, and one `all_story_runs` unit is taken per run id, as today.
- `runStoryRun` branches on kind: a scene skips the story writer and the word check, and runs the picture prompt writer with a scene prompt (dialogue inside tags, "scene content only", one scene, invented characters, never a real person's likeness), then the picture maker.
- `buildScenePrompt` assembles the image prompt in code, with the lines in speech bubbles exactly as written, like `buildPicturePrompt`.
- Status, redo (Try again prompt free, Draw again one unit) and picture routes carry `kind`. Timeouts stay 90 s / 120 s.

## Definition of Done

**Done when:** A scene run records a prompt step and a picture step and no story step, takes one allowance unit at start and one per Draw again, and keeps the speech-bubble lines verbatim in the stored prompt.

- [ ] tests: 20 mixed story and scene starts in one UTC day succeed and the 21st is refused; a repeated scene run id takes nothing; Try again of the prompt leaves `used` unchanged
- [ ] stalling stub providers fail the prompt step at 90 s and the picture step at 120 s
- [ ] a test asserts dialogue text in the prompt-writer request sits inside its tags and the assembled prompt holds each line verbatim
- [ ] a test walks every `public: true` route and none creates a run (AC-22)
- [ ] `npm test` and `npm run typecheck` pass

## Notes

- Shares `src/story/` files with nothing else in this epic.
- L: at the one-day limit. Split the prompt work from the routes if it grows.
