---
id: T19
title: "Show the main screen as a pager with one read-only dialogue page per dialogue"
layer: "ui"
deps: ["T17", "T13"]
acs: ["AC-01", "AC-02", "AC-05", "AC-06", "AC-10", "AC-11"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "lib/features/word_input/widgets/dialogue_page.dart", "test/main_screen_pager_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T19 — Show the main screen as a pager with one read-only dialogue page per dialogue

## Why

[sad §4](../sad.md) "Mobile UI architecture", ux-flows SCR-01, SCR-02.

## What

- Only when the current session has visible dialogues, the body becomes a `PageView`. Page 1 is today's screen, unchanged, with the speed dial; then one page per dialogue in order, with a small page indicator.
- `dialogue_page.dart`: the lines with every dialogue word's places bold (`matchPlaces`), the list of those words with translation and definition, and the scene picture from `StoryPictureStore` once drawn. Read only.
- After Done the screen stays on page 1. A session from History or after a restart shows its pages again (AC-10).

## Definition of Done

**Done when:** A session without dialogues renders exactly as before with no pager; one with dialogues pages through them with correct bold words and lists, and follows edits.

- [ ] widget tests: no dialogues → no `PageView`; two dialogues → three pages in order; a word in two dialogues bold on both; an edited translation shows
- [ ] `flutter analyze` clean

## Notes

- Reuses the existing text styles and the story screen's picture widget; adds no package.
