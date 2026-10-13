---
id: T14
title: "Add the Done filter, the edit rule and the card names for dialogues"
layer: "domain"
deps: ["T12", "T13"]
acs: ["AC-03", "AC-11", "AC-13", "AC-26"]
files_hint: ["lib/core/dialogues/dialogue_rules.dart", "test/dialogue_rules_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T14 — Add the Done filter, the edit rule and the card names for dialogues

## Why

[sad §4](../sad.md) "Results dialog unchanged" and choice 5, spec AC-03, AC-11, AC-13, AC-26.

## What

- `atDone(dialogues, keptWords)`: links each dialogue to the kept rows' `rowId`s, drops removed words, drops dialogues left with none (AC-03).
- `afterEdit(session)`: a deleted row leaves; an edited word stays only where it still appears (`appears`); a dialogue with no words left disappears, or is marked `hidden` while its import is pending delivery (ADR-0005). Links only shrink: a new or re-typed row never joins (AC-11, AC-26).
- `cardName(dialogue, others)`: the first line without speaker marks, cut to 40 characters with "…", with "(2)", "(3)" for repeats (AC-13).

## Definition of Done

**Done when:** The AC-03, AC-11, AC-13 and AC-26 examples from the spec pass as unit tests, including a pending dialogue that becomes hidden instead of removed.

- [ ] unit tests per example
- [ ] `flutter analyze` clean

## Notes

- Pure functions; the notifier wiring is T17 and T18.
