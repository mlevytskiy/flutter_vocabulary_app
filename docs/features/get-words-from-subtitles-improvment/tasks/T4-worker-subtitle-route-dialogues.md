---
id: T4
title: "Accept the dialogues flag on POST /subtitles/words and return the checked dialogues"
layer: "ports"
deps: ["T3"]
acs: ["AC-01", "AC-02", "AC-07", "AC-08", "AC-09"]
files_hint: ["vocab-photo-api/src/subtitles/routes.ts", "vocab-photo-api/test/subtitles-dialogues-route.test.mjs", "vocab-photo-api/test/anthropic-stub.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T4 — Accept the dialogues flag on POST /subtitles/words and return the checked dialogues

## Why

[sad §6](../sad.md) critical flow 1, [ADR-0002](../adr/0002-pick-words-and-dialogues-in-one-ai-request.md), [sad §7](../sad.md) mixed-version behaviour.

## What

- `readRequest` accepts an optional boolean `dialogues`. Any other type is `bad_request`.
- When set, the route passes it to the request builder and returns `dialogues: [{lines, words}]` beside `words`, after `keepWords` and `checkDialogues`. With no qualifying dialogue it returns `dialogues: []` (AC-07).
- Still one allowance unit per import. A no-English file answers `no_english_lines` as today (AC-09). The `logEvent` gains dialogues asked/returned/kept counts, never text.

## Definition of Done

**Done when:** Through the Anthropic stub: with the flag, the reply carries checked dialogues; without it, the response is today's; a cut-off reply with dialogues answers `words_not_picked`.

- [ ] route tests for flag on / off / malformed / cut off / no English
- [ ] existing subtitle route tests unchanged and green
- [ ] `npm test` passes

## Notes

- None.
