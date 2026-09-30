---
id: T3
title: "Build the pick-words prompt, the per-model request and the reply check, with a local AI stub for tests"
layer: "app"
deps: []
acs: ["AC-06", "AC-07", "AC-08", "AC-19", "AC-21"]
files_hint: ["vocab-photo-api/src/subtitles/prompt.ts", "vocab-photo-api/src/env.ts", "vocab-photo-api/scripts/test.mjs", "vocab-photo-api/test/anthropic-stub.mjs", "vocab-photo-api/test/subtitles-prompt.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T3 — Build the pick-words prompt, the per-model request and the reply check, with a local AI stub for tests

## Why

[sad §4](../sad.md) One AI call per import, and Ranking, exclusion and the limit; [ADR-0004](../adr/0004-let-the-learner-pick-the-subtitle-model-from-a-worker-allow-list.md); [sad §8](../sad.md) Prompt injection; [contracts/openapi.yaml](../contracts/openapi.yaml) `SubtitleModel`, `SubtitleWord`.

## What

- `src/subtitles/prompt.ts`: `SUBTITLE_MODELS` (the four ids from the contract), `buildSubtitleRequest(model, purpose, level, maximum, lines)` putting the lines in the user turn as data, and `parseSubtitleReply(response)` → `{kind: 'words', words, usage}` | `{kind: 'no_english'}` | throws.
- Per-model settings (reasoning or thinking options, output limit) live in one table in this file.
- `env.ts`: add `ANTHROPIC_API_URL?` (unset in production), mirroring `MW_API_URL`.
- `test/anthropic-stub.mjs` + `scripts/test.mjs`: a local stub that replays canned replies (complete, empty, no-English, cut off, malformed, slow) and records the calls it received, passed as `--var ANTHROPIC_API_URL:…`.

## Definition of Done

**Done when:** For each purpose and level the system prompt states the level scale, the purpose ranking rule, the exclusions (names, captions, marks), "maximum + 10 ranked candidates" and the JSON shape; each allow-listed model gets a valid request (max_tokens 16,000); the reply check accepts a complete list or the no-English flag and rejects a cut-off (`stop_reason: max_tokens`), non-JSON or wrongly shaped reply; `ANTHROPIC_API_URL` points the Worker at a local stub in `npm test`.

- [ ] unit tests over the prompt text for both purposes and a level
- [ ] the request builder output for each of the four models
- [ ] `parseSubtitleReply` over the six canned replies
- [ ] `npm test` and `tsc` clean
- [ ] the photo `/analyze` call is untouched (it keeps `claude-sonnet-5` and its own URL, spec AC-21)
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- Level and purpose are judged by the model (sad §4); no word-frequency list on the server.
- The stub is shared with T4's route tests.
