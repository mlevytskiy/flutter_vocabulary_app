---
id: T9
title: "Render the dialogue pages after the word table on the shared page"
layer: "ui"
deps: ["T6", "T2"]
acs: ["AC-20", "AC-22"]
files_hint: ["vocab-photo-api/src/session/page.ts", "vocab-photo-api/src/session/style.ts", "vocab-photo-api/test/page-dialogues.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T9 — Render the dialogue pages after the word table on the shared page

## Why

[sad §4](../sad.md) "Web UI architecture: unchanged", ux-flows SCR-11, spec AC-20.

## What

- The server-rendered page adds one dialogue page per dialogue after the table, in phone order. Each has its lines with every dialogue word's places in `<strong>`, the list of those words (word, translation, definition), and the scene picture when arrived.
- Fits both existing layouts (wide and phone) with no new layout. Reached by paging or swiping after the table, as ux-flows assumes.
- No control edits a dialogue's text or draws a picture (AC-22). A session without dialogues renders exactly as today.

## Definition of Done

**Done when:** A published session with dialogues renders one dialogue page each, in order, with correct bold places and the arrived picture; one without dialogues renders byte for byte as before.

- [ ] page tests: two dialogues in order; bold places match `matchPlaces`; a picture shown only once arrived; no dialogues → unchanged HTML snapshot
- [ ] `npm test` passes

## Notes

- Builds on the existing page markup and styles; adds no package or build step (good-looking-web ADR-0002).
