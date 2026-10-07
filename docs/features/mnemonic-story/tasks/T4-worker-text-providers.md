---
id: T4
title: "Add the Anthropic and OpenCode Zen text adapters with a 90 s limit"
layer: "infra"
deps: ["T2"]
acs: ["AC-08b"]
files_hint: ["vocab-photo-api/src/story/providers/text.ts", "vocab-photo-api/src/story/providers/anthropic.ts", "vocab-photo-api/src/story/providers/opencode-zen.ts", "vocab-photo-api/src/story/prompts.ts", "vocab-photo-api/src/env.ts", "vocab-photo-api/test/zen-stub.mjs", "vocab-photo-api/test/story-text-providers.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T4 — Add the Anthropic and OpenCode Zen text adapters with a 90 s limit

## Why

[sad §4](../sad.md) "New providers" and "Timeouts"; [sad §5](../sad.md) `src/story/providers/`; [spec AC-08b](../spec.md).

## What

- `writeText({model, system, user, timeoutMs}) → {text, usage} | {failed: 'refused'|'error'|'timeout', usage?}`, dispatched by the model's provider.
- Anthropic reuses `ANTHROPIC_API_KEY` / `ANTHROPIC_API_URL`. OpenCode Zen is OpenAI-compatible, with new `OPENCODE_ZEN_API_KEY` / `OPENCODE_ZEN_API_URL` in `env.ts`.
- `prompts.ts`: the story writer prompt (Ukrainian sentences joined by "→", one per word, each English word embedded as written; the owner's sample as the example) and the picture prompt writer prompt.
- `AbortController` at 90 s. `test/zen-stub.mjs` sits beside `anthropic-stub.mjs`.

## Definition of Done

**Done when:** `writeText` returns the text and token usage from either provider, turns a refusal or error into a failure, and aborts at 90 s (a test override shortens it), all checked against the stubs in `story-text-providers.test.mjs`.

- [ ] happy path, refusal, error and timeout per provider
- [ ] usage is passed through for pricing
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Shares `env.ts` with T5 and T8, so they are serialized.
