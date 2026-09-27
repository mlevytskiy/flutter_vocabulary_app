---
id: T5
title: "Accept definitions and the detail mode in published sessions"
layer: "ports"
deps: []
acs: ["AC-16", "AC-17", "AC-19"]
files_hint: ["vocab-photo-api/src/session/types.ts", "vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/src/session/store.ts"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T5 — Accept definitions and the detail mode in published sessions

## Why

Derives from [ADR-0004](../adr/0004-record-the-detail-mode-in-the-published-session.md) and [sad §8 field limits](../sad.md).

## What

`SessionEntry` gains optional `definition`; the session document gains optional `detail` (translation / definition / both). `parseEntries` accepts `definition` (string, ≤ 500 chars after trim, error names the offending word), treats a row as blank only when word, translation and definition are all empty, and validates `detail`. A document without `detail` reads as translation everywhere.

## Definition of Done

- [ ] `npm run typecheck` clean.
- [ ] curl: a create request with definitions + `detail: definition` stores both; a 501-character definition is refused with a message naming the word (AC-19); an old-shape request (no definition, no detail) still succeeds (AC-17).
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Deploy this before the app publishes definitions (ADR-0004 deploy order).

## Verification (2026-09-27, `wrangler dev`)

- RED: a 501-character definition was accepted (`200` + link) before the change.
- After: 501-character definition → `400 The definition of "gated" is too long (at most 500 characters)` (AC-19); `detail: "all"` → 400; an old-shape request (no `detail`, no `definition`) → 200 (AC-17).
- A definition-mode publish stores `detail: "definition"` and the definition-only row, and drops the all-blank trailing row (read back from local KV).
- `npm run typecheck` clean.
