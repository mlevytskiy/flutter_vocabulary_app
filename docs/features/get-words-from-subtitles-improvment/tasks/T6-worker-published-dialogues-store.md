---
id: T6
title: "Store dialogues with a published session and carry them in publish and republish"
layer: "infra"
deps: ["T1", "T2"]
acs: ["AC-20", "AC-22"]
files_hint: ["vocab-photo-api/src/session/dialogues.ts", "vocab-photo-api/src/session/store.ts", "vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/src/session/types.ts", "vocab-photo-api/test/publish-dialogues.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T6 — Store dialogues with a published session and carry them in publish and republish

## Why

[sad §4](../sad.md) choice 5, [ADR-0005](../adr/0005-add-an-imports-rows-and-dialogues-to-the-published-session-automatically.md); good-looking-web ADR-0006 and ADR-0008.

## What

- `POST /sessions` accepts optional `dialogues: [{id, lines, entries: number[], picture?: {mediaType}}]`, where `entries` are positions in `entries`, and stores them in `dialogues` / `dialogue_words` linked to the new row ids.
- A republish replaces dialogues together with rows, under the same link (ADR-0008).
- `dialogues.ts` holds the D1 reads and writes and the bounds: ≤ 10 per import, ≤ 8 lines, ≤ 200 characters a line, entries in range. The whole body still fits the existing size limits.
- Older apps sending no `dialogues` publish exactly as today.

## Definition of Done

**Done when:** Publishing with dialogues stores them linked to the right rows; republishing replaces them; publishing without them is unchanged.

- [ ] tests: publish with 2 dialogues → rows and dialogue words linked; republish replaces; out-of-range entry → 400; no `dialogues` field → today's result
- [ ] existing publish tests green
- [ ] `npm test` passes

## Notes

- None.
