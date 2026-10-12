---
id: T14
title: "Make an open panel own the main screen's touches and close on a session change"
layer: "wiring"
deps: ["T13"]
acs: ["AC-11", "AC-15b", "AC-16", "AC-17"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "lib/features/word_input/photo_panel/photo_panel.dart", "test/main_screen_photo_panel_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T14 — Make an open panel own the main screen's touches and close on a session change

## Why

[spec AC-11, AC-15b, AC-16, AC-17](../spec.md), [sad §8 "Touch ownership"](../sad.md), [ADR-0001](../adr/0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value.md) (overlay above the drawer, SnackBar and busy overlay), sad §6 Flow 6 and Flow 8.

## What

- While open: an `AbsorbPointer`-style layer over the rows' controls, top bar and floating buttons whose tap closes the panel; in half-open, vertical drags still reach the list's `Scrollable`; `drawerEnableOpenDragGesture` off.
- Hide the tab while the drawer is open; close before any `context.push` / typed-route call from the screen; close and clear on a current-session id change.

## Definition of Done

**Done when:** `main_screen_photo_panel_test.dart` passes the new cases: with the panel open a tap on a row, the top bar, its menu or the floating buttons only closes it (no focus, no handler, no route), the visible list still scrolls in half-open, the drawer does not open and the tab is hidden while the drawer is open, a new current session id closes the panel and clears the selection, pushing another route closes it first, a background/resume with the same session keeps stop and selection, and the tab ignores touches while busy.

- [ ] test: tap row field, delete, lightning, dots, AppBar action, speed dial, settings button while half-open
- [ ] test: switch session through the notifier
- [ ] test: `AppLifecycleState.paused` then `resumed`
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- sad §6 "Flagged for design": History, the drawer and RESTORE are reachable only after the panel closes; re-check with #22's code that no other path changes the session while open.
