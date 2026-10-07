---
id: T8
title: "Carry dialogues and scene-picture arrivals in the shared page's change feed"
layer: "ports"
deps: ["T6", "T2"]
acs: ["AC-20", "AC-21"]
files_hint: ["vocab-photo-api/src/session/changes.ts", "vocab-photo-api/test/changes-dialogues.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T8 — Carry dialogues and scene-picture arrivals in the shared page's change feed

## Why

[sad §4](../sad.md) choice 5, good-looking-web ADR-0005, spec AC-21.

## What

- The feed answers, beside rows, every dialogue whose `added_rev`, `picture_arrived_rev`, or any linked row's revision is above the cursor. Each comes with its lines, its picture link if arrived, and its current dialogue words: the linked rows still alive whose word still `matchPlaces` the text, each with the bold places, word, translation and definition (AC-11 rules applied to the page's data).
- A dialogue left with no words is sent as removed, so the page drops it (AC-26 on the page).
- Read in the same D1 batch as rows, so the answer is one snapshot.

## Definition of Done

**Done when:** After a partner edits a dialogue word's translation, deletes its row, or edits its word so it no longer appears, the next feed answer carries that dialogue in its new state.

- [ ] tests for: new dialogue appended; picture arrived; translation edited; row deleted; word edited out of the text; all words gone → removed
- [ ] existing change-feed tests green
- [ ] `npm test` passes

## Notes

- None.
