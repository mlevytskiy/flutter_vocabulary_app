---
id: T1
title: "Add the pure settle rule and the photo panel controller"
layer: "domain"
deps: []
acs: ["AC-05", "AC-08", "AC-15"]
files_hint: ["lib/features/word_input/photo_panel/photo_panel_stops.dart", "lib/features/word_input/photo_panel/photo_panel_controller.dart", "test/photo_panel_stops_test.dart", "test/photo_panel_controller_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Add the pure settle rule and the photo panel controller

## Why

[spec AC-08, AC-05, AC-15](../spec.md), [sad §4 "State placement" and §5](../sad.md), [ADR-0001](../adr/0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value.md) (one openness value, stops at 0, 0.5, 1).

## What

- `photo_panel_stops.dart`: a pure `settle(startStop, openness, velocity)` returning closed, half-open or full-open. Nearest stop on a slow release; a flick moves one stop beyond the start stop in its direction and never two; a leftward drag that started at closed never settles closed.
- `photo_panel_controller.dart`: `PhotoPanelController extends ChangeNotifier` holding the current stop and the selected photo id. `select(id)` toggles (same id clears, another id moves); `close()` and `stepBack()` clear the selection when the stop becomes closed; `retain(ids)` clears a selected photo that is no longer in the list. Nothing is saved.

## Definition of Done

**Done when:** `photo_panel_stops_test.dart` and `photo_panel_controller_test.dart` pass: settle picks the nearest stop, a flick moves exactly one stop past the start stop, any leftward drag from closed gives at least half-open, and only one photo is ever selected (same photo again clears, another moves, close clears, a vanished photo clears).

- [ ] test: unit table for `settle`: every start stop × release openness × slow / fast left / fast right
- [ ] test: controller: toggle, move, clear on close, clear on `retain` without the selected id, listeners notified once per change
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Pure Dart, no widgets: runs in the smoke time budget.
- Spec §8 open question "step to the next highlighted row" is taken at its default (no), so the controller keeps one selected photo and nothing more.
