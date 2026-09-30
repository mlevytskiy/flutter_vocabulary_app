---
id: T4
title: "Serve POST /subtitles/words per the contract and register it behind the app secret"
layer: "ports"
deps: ["T2", "T3"]
acs: ["AC-06", "AC-10", "AC-12", "AC-13", "AC-14", "AC-15", "AC-19", "AC-20", "AC-21"]
files_hint: ["vocab-photo-api/src/subtitles/routes.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/subtitles.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T4 — Serve POST /subtitles/words per the contract and register it behind the app secret

## Why

[contracts/openapi.yaml](../contracts/openapi.yaml) and [api-sync-report.md](../contracts/api-sync-report.md); [sad §6 F3](../sad.md) for the order of checks; [sad §8](../sad.md) Abuse bounds, Logging, Complete or nothing.

## What

- `src/subtitles/routes.ts`: parse and bound the body (lines 1..n of ≤ 200 chars and ≤ 1,048,576 UTF-8 bytes in total, body ≤ 2 MB, sessionWords ≤ 500 × ≤ 500 chars, maximum 1–100, level and purpose enums), check the model allow-list, `takeSubtitleImport`, then the AI call with an `AbortController` at 225 s, `parseSubtitleReply`, drop session words case-insensitively and duplicates, keep the first `maximum`.
- Answer with the contract's `{error, code}` bodies and statuses; define the new codes as constants here.
- Add `subtitleRoutes` to `ROUTES` in `src/index.ts` with `public: false`.
- Log one `logEvent` line per import (model, input and output tokens, AI ms, words returned, outcome, refusal reason) and never the lines or session words.

## Definition of Done

**Done when:** Every response in contracts/openapi.yaml is produced by a test through `npm test`: 200 with ≤ maximum words, none in sessionWords (any case), no duplicates, in rank order, and 200 with an empty list; 400 bad_request / unknown_model and 413 too_large before the allowance is touched; 401 without the secret; 429 too_many_imports with the stub AI not called; 422 no_english_lines; 502 words_not_picked for a cut-off, malformed or 225 s-late reply.

- [ ] one test per contract response, using the T3 stub
- [ ] 11 imports in a window → the 11th is refused and the stub received exactly 10 calls (sad §10 QG-3)
- [ ] 21 imports in a day from 3 addresses → the 21st is refused
- [ ] a 201-character line → 400; lines of 1,048,576 + 1 bytes → 413; the stripped lines of a 1 MB fixture → accepted
- [ ] `npm test` and `tsc` clean
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- Shares `src/index.ts` with T2 (lane serialized by files_hint).
- In tests the address comes from `cf-connecting-ip`; check how `wrangler dev` fills it locally and send the header explicitly if the tests need several addresses.
