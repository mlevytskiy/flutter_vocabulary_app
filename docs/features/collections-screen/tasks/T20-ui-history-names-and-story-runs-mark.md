---
id: T20
title: "Show name and word count in History rows, and mark story runs of an erased collection"
layer: "ui"
deps: ["T8"]
acs: ["AC-28"]
files_hint: ["lib/features/history/history_screen.dart", "lib/features/words_settings/", "test/history_screen_test.dart", "test/story_runs_screens_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T20 — Show name and word count in History rows, and mark story runs of an erased collection

## Why

[screens SCR-11](../screens.md) and "Not in the ux-flows inventory", [sad §5](../sad.md#5-building-block-view) story runs after an erase, [sad §6](../sad.md#6-runtime-view) F11.

## What

- History reads `watchHistory()` (T8).
- The deleted-collection mark is worked out at display time; `StoryRun` does not change.

## Definition of Done

**Done when:** Widget tests cover SCR-11 default and empty: rows show the name with "N words" beside it and the date below, the current one still marked, binned and empty collections not listed, empty text "No collections yet"; a story run whose collection no longer exists shows "From a deleted collection" and keeps its picture.

- [ ] SCR-11 default and empty built
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
