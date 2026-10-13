---
id: T3
title: "Ask for dialogues in the subtitle prompt and check them in the reply"
layer: "domain"
deps: ["T2"]
acs: ["AC-04", "AC-05", "AC-07", "AC-08"]
files_hint: ["vocab-photo-api/src/subtitles/prompt.ts", "vocab-photo-api/src/subtitles/dialogues.ts", "vocab-photo-api/test/subtitles-dialogues.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T3 — Ask for dialogues in the subtitle prompt and check them in the reply

## Why

[sad §4](../sad.md) choice 2, [ADR-0002](../adr/0002-pick-words-and-dialogues-in-one-ai-request.md), [sad §8](../sad.md) Complete or nothing and Prompt injection.

## What

- `buildSubtitleRequest` takes `dialogues: boolean`. When true, it appends a dialogue block to the system prompt: up to 10 jokes or memorable exchanges, ≤ 8 lines each, lines may be lightly edited, each naming the returned words it holds. It extends the JSON shape with `dialogues: [{lines: string[], words: string[]}]` and sets `max_tokens` 20000. When false, everything stays byte for byte today's.
- `parseSubtitleReply` accepts the `dialogues` array only when asked. A missing or malformed array throws `SubtitleReplyError` (AC-08).
- New `dialogues.ts` `checkDialogues(dialogues, keptWords)`: drops links to words not kept by `keepWords`, unlinks words with no `matchPlaces`, drops dialogues over 8 lines, any line over 200 characters, or left without words, and keeps the first 10 (AC-04, AC-05). A word may stay linked to several dialogues (AC-06).

## Definition of Done

**Done when:** With `dialogues: false` the request equals a snapshot of today's `buildSubtitleRequest`, and `checkDialogues` drops exactly the AC-04/AC-05 cases in the tests.

- [ ] a snapshot test compares system prompt, `max_tokens` and body with and without the flag
- [ ] tests: 11 dialogues → 10; a 9-line dialogue dropped; a link to an unreturned word ignored; a linked word absent from the text unlinked; a dialogue left empty dropped; a malformed `dialogues` array throws
- [ ] `npm test` and `npm run typecheck` pass

## Notes

- QG-1 and QG-2 of [sad §10](../sad.md) are verified here.
