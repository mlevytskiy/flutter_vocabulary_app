---
id: T15
title: "Prove words from a set behave like typed words in the table, History and export"
layer: "tests"
deps: ["T13"]
acs: ["AC-17"]
files_hint: ["test/quizlet_words_ordinary_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T15 — Prove words from a set behave like typed words in the table, History and export

## Why

spec AC-17, US-06; [sad §6 F6](../sad.md); `docs/lightning_icon_rules.md`.

## What

- Widget and export tests over a session holding set words; no production change expected — if one is needed, it is a bug fix inside this task.

## Definition of Done

**Done when:** Tests show a word kept from a card with a back has a filled definition and no definition lightning, one without a back shows the lightning, a real translation shows none, and the words table, a History-reopened session and the AnkiDroid export list set words like other words.

- [ ] tests pass
- [ ] `flutter analyze` clean
