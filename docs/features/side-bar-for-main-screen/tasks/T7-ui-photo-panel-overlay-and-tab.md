---
id: T7
title: "Draw the photo tab in an overlay and let it be dragged up or down"
layer: "ui"
deps: ["T2", "T3", "T6"]
acs: ["AC-01", "AC-02", "AC-14", "AC-17"]
files_hint: ["lib/features/word_input/photo_panel/photo_panel.dart", "test/photo_tab_position_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T7 — Draw the photo tab in an overlay and let it be dragged up or down

## Why

[spec AC-01, AC-02, AC-14, AC-17](../spec.md), [ADR-0001](../adr/0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value.md), [sad §4 choice 2 and §8 "Touch ownership", "Drag direction"](../sad.md), sad §6 Flow 3, ux-flows SCR-01.

## What

- `PhotoPanel` widget: an `OverlayPortal` child that draws nothing while `photosWithWordsProvider` is empty, otherwise the chosen look's tab at the right side at `photoTabTopProvider`'s clamped height, honouring `MediaQuery.viewInsets` for the keyboard and the floating-button row and SnackBar for its lowest position.
- The tab takes every touch on it (it is hit-tested first). Past the touch slop, a mainly vertical drag moves the tab and saves its height on release; a mainly leftward drag is handed to the opening logic of T8 (a stub until then). One drag never does both.
- A `busy` input (the screen's `_isAnalyzingPhoto`) makes the tab ignore touches. Previews are loaded after the first frame.
- With `hidesTabWhileScrolling` true, the tab fades while a scroll notification is active.

## Definition of Done

**Done when:** `photo_tab_position_test.dart` passes: no photo with words draws nothing; the tab sits beside the first rows, then at the kept height after a vertical drag and a restart; it stays put while the list scrolls; it rides above the keyboard and returns; it stays between the top bar and the floating buttons (and above a SnackBar); a touch while busy is ignored.

- [ ] test: host the panel over a fake list of rows; no `PhotoPanel` content with an empty provider
- [ ] test: vertical drag then remount reads the kept height
- [ ] test: diagonal drag goes by its main direction
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Mounting on the real main screen is T13; this task tests the panel on a host scaffold.
- First of the `photo_panel.dart` lane (T7 → T8 → T9 → T10 → T11).
