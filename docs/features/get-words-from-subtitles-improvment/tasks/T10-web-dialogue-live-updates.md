---
id: T10
title: "Keep the shared page's dialogue pages in step with the change feed"
layer: "ui"
deps: ["T8", "T9"]
acs: ["AC-20", "AC-21"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/client/page.d.ts", "vocab-photo-api/test/page-client-dialogues.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T10 — Keep the shared page's dialogue pages in step with the change feed

## Why

[sad §4](../sad.md) choice 5, spec AC-20 and AC-21.

## What

- The page script applies the feed's dialogues: it adds new dialogue pages at the end, re-renders a changed dialogue's bold places and word list from the feed's data, shows a newly arrived picture, and drops a removed dialogue.
- A partner's own edit or delete of a dialogue word shows on its dialogue page after the next poll, without reloading.
- Typed text in the table is never lost by a dialogue re-render (good-looking-web AC-36).

## Definition of Done

**Done when:** With the page open, a dialogue appended by the app, a picture arriving, and a partner's translation edit or row delete each show on the dialogue page after one poll.

- [ ] client tests with a fake feed for add / change / picture / remove
- [ ] `npm test` passes

## Notes

- None.
