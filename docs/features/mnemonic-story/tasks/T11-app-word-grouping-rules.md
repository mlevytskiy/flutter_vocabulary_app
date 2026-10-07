---
id: T11
title: "Add the pure word-grouping rules to the app"
layer: "domain"
deps: ["T10"]
acs: ["AC-01", "AC-02", "AC-02b", "AC-03", "AC-04", "AC-05", "AC-17"]
files_hint: ["lib/core/story/word_grouping.dart", "test/word_grouping_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T11 — Add the pure word-grouping rules to the app

## Why

[ADR-0005](../adr/0005-let-the-app-own-the-grouping-rules-and-the-ai-only-split-words.md); [sad §6](../sad.md) S-01, S-08; CONTEXT invariants.

## What

- `groupedWordsKey(session)`: row id + English word of each word to learn. A translation or definition edit does not change it (AC-03).
- `planGrouping(session, runsInProgress)` → `unchanged` | `local(groups)` (AC-02, AC-02b) | `ask(words, keep)` (AC-05). A group with a story or a run in progress is never sent.
- `applySplit(session, split)` → `ok(groups, waiting)` | `invalid`: every word once, 7 to 19 above 19, keep groups only gain words and keep id, name and selection, fewer than 7 leftovers wait (AC-04, AC-05).
- `groupWords(session, group)`: current words by row id, so deleted words leave and edited words show the new form. `isOutdated(group)` compares them with `storyWords` (AC-17).
- Selection fallback: the remembered group, else the first (AC-01).

## Definition of Done

**Done when:** `test/word_grouping_test.dart` covers each AC-01–AC-05 rule, AC-02b's own small group, AC-03's change rule (translation edits ignored) and AC-17's outdated rule, with no Worker or Isar involved.

- [ ] a split that drops, doubles or mis-sizes a word is `invalid`
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Pure Dart in `lib/core/story/` (architecture.md §2 rule 3, critic resolution).
