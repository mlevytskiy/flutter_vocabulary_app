---
id: T25
title: "Replace \"session\" with \"collection\" in every text the learner reads"
layer: "ui"
deps: ["T2", "T20"]
acs: ["AC-33"]
files_hint: ["lib/features/", "test/"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T25 — Replace "session" with "collection" in every text the learner reads

## Why

[spec AC-33](../spec.md#ac-33-us-14--happy), [sad §8](../sad.md#8-crosscutting-concepts) Internationalisation.

## What

- Strings only; layout and style unchanged (CLAUDE.md rule 3).

## Definition of Done

**Done when:** `grep -rni "session" lib --include='*.dart'` finds no user-visible string (only identifiers pinned by `@Name`, prefs keys and Worker field names), and widget tests check the reworded History empty text, photo panel heading, Notes tag field and import results.

- [ ] grep result attached to the task
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

After T20 because both touch History's empty text.
