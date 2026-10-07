---
id: T7
title: "Add the append route and the scene-picture upload route for a published session"
layer: "ports"
deps: ["T6"]
acs: ["AC-20", "AC-22"]
files_hint: ["vocab-photo-api/src/session/dialogues.ts", "vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/test/append-dialogues.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T7 — Add the append route and the scene-picture upload route for a published session

## Why

[sad §4](../sad.md) choice 5, [ADR-0005](../adr/0005-add-an-imports-rows-and-dialogues-to-the-published-session-automatically.md), [sad §8](../sad.md) Authentication and Sync.

## What

- App-secret route to append to a published session: requires that session's edit token; body `{importId, entries: [{word, translation, definition?}], dialogues: [{id, lines, entries: number[]}]}`. Rows are added after the existing ones and dialogues after the existing dialogues, all at one new revision. A repeated `importId` adds nothing and answers the same.
- App-secret route to upload a scene picture's bytes for a dialogue (edit token required, idempotent once the bytes have arrived). Bytes go to R2 under the session's prefix, `picture_arrived_rev` is set.
- Public read route for a scene picture, as for source photos.
- An expired or unknown session answers `gone`. A wrong token is refused. The page can call neither write route.

## Definition of Done

**Done when:** An append adds rows and dialogues once per import id without touching existing rows; a picture upload makes the picture readable by its public link; wrong token and expired link are refused.

- [ ] tests: append twice with one import id → one copy; partner edits on existing rows survive an append; wrong edit token → refused; expired → gone; picture upload then public read returns the bytes
- [ ] `npm test` passes

## Notes

- Shares `dialogues.ts` and `handlers.ts` with T6, so they run in one lane.
