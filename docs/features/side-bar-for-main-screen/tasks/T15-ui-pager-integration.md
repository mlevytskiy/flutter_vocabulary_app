---
id: T15
title: "Keep the tab on every pager page and open the panel only over the words page"
layer: "ui"
deps: ["T14"]
acs: ["AC-13"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "lib/features/word_input/photo_panel/photo_panel.dart", "test/photo_panel_pager_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T15 — Keep the tab on every pager page and open the panel only over the words page

## Why

[spec AC-13](../spec.md), [sad §1 Decision override and §11 first risk](../sad.md), [ADR-0001](../adr/0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value.md), sad §6 Flow 7, ux-flows SCR-04.

## What

- Mount `PhotoPanel` above #22's `PageView` (not inside page 1), so the tab stays put across pages.
- Give `PhotoPanel` an `onBeforeOpen` that animates the `PageController` to the words page and waits; set the `PageView`'s physics to `NeverScrollableScrollPhysics` while the stop is not closed.

## Definition of Done

**Done when:** `photo_panel_pager_test.dart` passes on a session with dialogues: a drag on the tab on the words page leaves `PageController.page` unchanged; opening from a dialogue page first animates to page 0 then settles; while open no swipe changes the page; while closed a swipe away from the tab changes the page; the tab does not move with a page swipe.

- [ ] test: two dialogues → three pages; drags, flings and a screen-reader tap from page 2
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- **Blocked until roadmap #22 is merged** (get-words-from-subtitles-improvment T19, the main screen pager). Re-read T19's code before starting and adjust only the mounting (sad §11).
- Without dialogues there is no `PageView` and the panel works as in T13.
