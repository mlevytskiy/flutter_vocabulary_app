---
id: T15
title: "Group dialogue words into dialogue groups before the existing grouping rules"
layer: "domain"
deps: ["T12"]
acs: ["AC-06", "AC-13", "AC-15", "AC-17", "AC-24", "AC-25"]
files_hint: ["lib/core/story/word_grouping.dart", "lib/core/story/word_groups_notifier.dart", "test/word_grouping_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T15 — Group dialogue words into dialogue groups before the existing grouping rules

## Why

[sad §4](../sad.md) "Grouping stays app-owned and local", mnemonic-story ADR-0005.

## What

- A dialogue pass first: in pager order, each visible dialogue gets a group (`dialogueId` set) of its dialogue words that are words to learn and in no group yet. Existing groups keep their words, name, story and selection (AC-17). A word in two dialogues goes to the first (AC-06).
- Dialogue groups are exempt from 7..19 (AC-15). Other words then follow the existing rules: one "Other words" group up to 19, else topic groups, with waiting words (AC-25).
- The notifier starts no story run for a dialogue group on opening or selection (AC-24), and reports that the group pager must always show when any dialogue group exists.
- A dialogue group whose words are all gone disappears, and its words still to learn return to other words (AC-26).

## Definition of Done

**Done when:** The AC-06, AC-15, AC-17, AC-24 and AC-25 examples pass as unit tests, and every existing grouping test still passes.

- [ ] new unit tests per example
- [ ] `word_grouping_test.dart` existing cases green
- [ ] `flutter analyze` clean

## Notes

- None.
