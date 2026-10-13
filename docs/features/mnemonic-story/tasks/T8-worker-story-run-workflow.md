---
id: T8
title: "Run each story run as a Workflow on the Worker"
layer: "app"
deps: ["T3", "T4", "T5", "T6"]
acs: ["AC-08", "AC-08b", "AC-09", "AC-10"]
files_hint: ["vocab-photo-api/src/story/workflow.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/src/env.ts", "vocab-photo-api/wrangler.jsonc", "vocab-photo-api/test/story-workflow.test.mjs"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T8 — Run each story run as a Workflow on the Worker

## Why

[ADR-0002](../adr/0002-run-each-story-run-as-a-cloudflare-workflow.md); [sad §6](../sad.md) S-03; [spec AC-08 – AC-10](../spec.md).

## What

- `StoryRunWorkflow extends WorkflowEntrypoint`, exported from `index.ts`, with the `workflows` binding `STORY_RUN` in `wrangler.jsonc` and `env.ts`.
- Steps run as `step.do` with `retries: { limit: 0 }`: story writer → `missedWords` → picture prompt writer → picture maker. Each records its result or failure, price (an estimate on timeout), time and missed words through `store.recordStep`, and the picture goes to R2.
- Params `{runId, mode: 'full'|'prompt'|'picture', pictureModel?, attempt}`, so a redo runs only that step (and the picture after a prompt redo).

## Definition of Done

**Done when:** Against the stub providers, a full run records story, prompt and picture with prices and times; a missed word stops at the story with the missed words; a writer, prompt or picture failure or timeout stops at that step; and every stub is called exactly once per step, including when the client disconnects mid-run, all in `story-workflow.test.mjs`.

- [ ] prompt-redo and picture-redo modes run only their step
- [ ] the picture is in R2 under `story-runs/<runId>/<attempt>`
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- L: about one day. If Workflows under `wrangler dev` resist testing, record it under sad §11 (the risk row exists) and test the step functions directly.
- Shares `index.ts` / `env.ts` with T4, T5, T7 and T9.
