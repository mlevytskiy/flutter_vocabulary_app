---
id: T11
title: "Add \"Dialogs from movie\" to the exercise list for the app and the web"
layer: "domain"
deps: []
acs: ["AC-16", "AC-22"]
files_hint: ["vocab-photo-api/src/learn/exercises.json", "lib/features/learn/exercises.dart", "vocab-photo-api/test/learn-exercises.test.mjs", "test/learn_exercises_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T11 — Add "Dialogs from movie" to the exercise list for the app and the web

## Why

[sad §4](../sad.md) "Exercise list", learn-part-step-1 ADR-0003, spec AC-16.

## What

- `{ "id": "dialogs-from-movie", "name": "Dialogs from movie", "stage": 1, "available": true }` right after `mnemonic-story`, making twelve.
- The app's const list follows, tested against the JSON as today.
- On the web learn page it can be ticked, and Start leads to the coming-soon screen as for Mnemonic story (AC-22). No web drawing path.

## Definition of Done

**Done when:** Both lists hold twelve exercises in the same order, and the web learn page's Start with "Dialogs from movie" ticked opens coming soon.

- [ ] `learn_exercises_test.dart` and `learn-exercises.test.mjs` green with twelve
- [ ] a web learn test: ticking it and Start → coming soon

## Notes

- The app-side session condition (greyed without dialogues) is T21.
