---
id: T9
title: "Show the large photos in full-open with zoom and neighbour-only decoding"
layer: "ui"
deps: ["T8"]
acs: ["AC-07b", "AC-09"]
files_hint: ["lib/features/word_input/photo_panel/photo_panel.dart", "lib/features/word_input/photo_panel/looks/look_a.dart", "test/photo_panel_full_open_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T9 — Show the large photos in full-open with zoom and neighbour-only decoding

## Why

[spec AC-07b, AC-09](../spec.md), [sad §4 "Zoom" and "Previews"](../sad.md), sad §6 Flow 5, ux-flows SCR-03.

## What

- The shared full-open behaviour in `PhotoPanel`: start index from the selected photo, `InteractiveViewer` per large photo, a decode window of the shown photo ± 1 at screen size (`PhotoPreview` with the screen width).
- Look A's browsing widget (a `PageView`) wired to it; browsing reports the shown index but never calls `controller.select`.

## Definition of Done

**Done when:** `photo_panel_full_open_test.dart` passes: full-open starts at the selected photo (or the first), a two-finger scale zooms with `InteractiveViewer`, a drag on a zoomed photo pans it and does not move the panel, browsing does not change the selected photo, a tap on a large photo does nothing, only the shown photo and its neighbours are decoded, and an unreadable photo shows the placeholder.

- [ ] test: selected photo 3 of 5 opens at index 3
- [ ] test: scale gesture zooms; drag while zoomed leaves openness at 1
- [ ] test: browse then `stepBack()` keeps the same highlight
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- `InteractiveViewer` as on the story picture; nothing imported from `mnemonic_story` or the words table.
