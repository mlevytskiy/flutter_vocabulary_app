---
id: T2
title: "Return where each word appears from the word check, and pin the rule with a shared case file"
layer: "domain"
deps: []
acs: ["AC-05", "AC-06", "AC-11"]
files_hint: ["vocab-photo-api/src/story/word-check.ts", "vocab-photo-api/src/story/match-cases.json", "vocab-photo-api/test/story-word-check.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T2 — Return where each word appears from the word check, and pin the rule with a shared case file

## Why

[sad §4](../sad.md) "One matching rule, two languages", [sad §8](../sad.md) Matching rule; spec AC-05.

## What

- Add `matchPlaces(text, word)` beside `missedWords` in `word-check.ts`: the character ranges where the word (or phrase) appears under the AC-08/AC-05 rule. It returns every place, so each one can be bold.
- `missedWords` keeps its behaviour, and is rebuilt on the same tokenizer.
- `match-cases.json`: cases `{text, word, places}` covering whole word, any case, phrases, the -s/-es/-ed/-ing endings, a word inside another word, apostrophes and repeats. The Dart port (T13) reads the same file.

## Definition of Done

**Done when:** `matchPlaces` returns the expected ranges for every case in `match-cases.json`, and the existing story word-check tests still pass.

- [ ] a test runs every case in `match-cases.json` through `matchPlaces`
- [ ] `story-word-check.test.mjs` unchanged and green
- [ ] `npm run typecheck` passes

## Notes

- Pure module, no I/O. It runs in the Worker, the page render (T9) and the change feed (T8).
