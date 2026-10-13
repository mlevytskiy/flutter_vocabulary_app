---
id: T16
title: "Show the group line, the group pager and grouping messages on the learn page"
layer: "ui"
deps: ["T14"]
acs: ["AC-01", "AC-02", "AC-02b", "AC-03", "AC-04", "AC-05", "AC-19"]
files_hint: ["lib/features/learn/learn_screen.dart", "lib/features/learn/widgets/group_pager.dart", "lib/features/words_table/words_table_screen.dart", "test/learn_groups_ui_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T16 — Show the group line, the group pager and grouping messages on the learn page

## Why

[ux-flows](../ux-flows.md) SCR-02, SCR-03 and Flow US-01; [sad §6](../sad.md) S-01, S-02. No `screens.md` (the stage was skipped), so the states come from ux-flows and the ACs.

## What

- `group_pager.dart`: a `PageView` of cards (name + words). Tap selects with the existing selected style of the learn page's tick tiles; swipe browses. Each card ≥ 48 dp.
- Learn page: the line "We grouped your words into sets of up to 19 words. Please select one group to learn." above the pager only with two or more groups, plus "Grouping your words…", "Could not group your words" + Try again, "N more words are waiting for a group (at least 7 are needed)" and the daily-limit text. Start stays unavailable for Mnemonic story while no group is selected.
- Words screen: calls `ensureGrouped()` quietly when it opens (AC-03).

## Definition of Done

**Done when:** Widget tests in `test/learn_groups_ui_test.dart` show each learn-page state (one group, several groups with the remembered one selected, grouping, failed with Try again, waiting N, daily limit), tap selecting versus swipe browsing, and Start unavailable while no group is selected.

- [ ] reuses the learn page's existing text styles, `ElevatedButton` and tile look; no new styling system
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- CLAUDE.md rule 3 is overridden only for the parts spec §1 lists.
