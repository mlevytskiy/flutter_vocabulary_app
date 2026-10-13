---
id: T21
title: "Offer \"Dialogs from movie\" on the learn page with dialogue groups"
layer: "ui"
deps: ["T11", "T15"]
acs: ["AC-13", "AC-15", "AC-16", "AC-24", "AC-25"]
files_hint: ["lib/features/learn/learn_screen.dart", "lib/features/learn/widgets/group_pager.dart", "test/learn_dialogues_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T21 — Offer "Dialogs from movie" on the learn page with dialogue groups

## Why

[sad §4](../sad.md) "Grouping" and "Exercise list", ux-flows SCR-06.

## What

- "Dialogs from movie" right after "Mnemonic story" in Step 1, tickable only when the session has dialogues, otherwise greyed with "Needs dialogues from subtitles" (AC-16).
- With any dialogue group, the group pager is always shown with "Your words are grouped by the dialogues from the film. Please select one group to learn." Cards use `cardName`, then "Other words", then topic groups (AC-13, AC-25).
- Selecting a dialogue group starts nothing (AC-24). Start with "Dialogs from movie" opens the dialogue screen for a dialogue group (T22), or the story screen for "Other words" and topic groups. With both exercises ticked, it opens them one after the other in list order.

## Definition of Done

**Done when:** In a session with dialogues the learn page shows the dialogue cards and the line, starts nothing on selection, and Start routes per AC-13; without dialogues the exercise is greyed and everything else is unchanged.

- [ ] widget tests per case, with `fake_story_groups.dart`
- [ ] existing `learn_screen_test.dart` and `learn_groups_ui_test.dart` green
- [ ] `flutter analyze` clean

## Notes

- Reuses the existing group pager and exercise rows.
