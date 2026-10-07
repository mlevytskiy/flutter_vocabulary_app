---
id: T5
title: "Add the Grok and Higgsfield picture adapters with a 120 s limit"
layer: "infra"
deps: ["T2", "T4"]
acs: ["AC-09", "AC-08b"]
files_hint: ["vocab-photo-api/src/story/providers/picture.ts", "vocab-photo-api/src/story/providers/xai.ts", "vocab-photo-api/src/story/providers/higgsfield.ts", "vocab-photo-api/src/env.ts", "vocab-photo-api/test/xai-stub.mjs", "vocab-photo-api/test/higgsfield-stub.mjs", "vocab-photo-api/test/story-picture-providers.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T5 — Add the Grok and Higgsfield picture adapters with a 120 s limit

## Why

[sad §4](../sad.md) "New providers" and "Timeouts"; [spec AC-09](../spec.md).

## What

- `drawPicture({model, prompt, timeoutMs}) → {bytes, contentType} | {failed}`.
- xAI via `XAI_API_KEY` / `XAI_API_URL`. Higgsfield via `HIGGSFIELD_API_KEY` / `HIGGSFIELD_API_URL`, submit and then poll within the same 120 s.
- Stubs for both providers, with refusal and slow-answer modes.

## Definition of Done

**Done when:** `drawPicture` returns picture bytes from either provider, turns a refusal or error into a failure, and stops at 120 s including Higgsfield's polling, checked against the stubs in `story-picture-providers.test.mjs`.

- [ ] happy path, refusal, error and timeout per provider
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Depends on T4 only through `env.ts` (serialized lane).
