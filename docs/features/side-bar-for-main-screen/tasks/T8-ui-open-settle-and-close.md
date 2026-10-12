---
id: T8
title: "Open the panel half-open and full-open, settle at stops, and step back"
layer: "ui"
deps: ["T1", "T7"]
acs: ["AC-03", "AC-07", "AC-08", "AC-10"]
files_hint: ["lib/features/word_input/photo_panel/photo_panel.dart", "test/photo_panel_open_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T8 — Open the panel half-open and full-open, settle at stops, and step back

## Why

[spec AC-03, AC-07, AC-08, AC-10](../spec.md), [ADR-0001](../adr/0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value.md) (one `AnimationController`, interpolated photo rectangles), sad §6 Flow 1, Flow 2, Flow 6, ux-flows SCR-02, SCR-03.

## What

- The openness `AnimationController` (0 → 0.5 → 1) in `PhotoPanel`'s `State`; drags move it directly and release calls `settle` (T1); the stop is written to `PhotoPanelController`.
- Half-open: the look's column of small photos as a lazy builder beside the rows; a tap on a photo calls `controller.select`. The expand control opens full-open.
- Full-open: each photo's rectangle interpolated from its small to its large place so the small photos grow into the large ones; the handle starts the drag back.
- `stepBack()` for the screen's `PopScope` (T13). Opening calls `FocusManager.instance.primaryFocus?.unfocus()`.

## Definition of Done

**Done when:** `photo_panel_open_test.dart` passes: a tap settles half-open within `pump(300 ms)` with no animation running and the small photos oldest first; a short left drag gives half-open, a longer one full-open, a flick one stop further; the expand control opens full-open; a drag back on the handle settles by the rule; `stepBack()` goes full-open → half-open → closed; opening unfocuses the field and keeps its text.

- [ ] test: `tester.tap`, `tester.drag`, `tester.fling` on the tab and the handle
- [ ] test: `pump(300 ms)` timing check (QG-2a)
- [ ] test: focused `TextField` loses focus with its text kept
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Same `photo_panel.dart` lane as T7, T9, T10, T11.
- The flick threshold lives in one constant next to `settle`.
