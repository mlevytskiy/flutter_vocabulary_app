---
id: T17
title: "Build design variant C"
layer: "ui"
deps: ["T11"]
acs: ["AC-19"]
files_hint: ["lib/features/word_input/photo_panel/looks/look_c.dart", "lib/features/word_input/photo_panel/looks/looks.dart", "test/photo_panel_look_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T17 — Build design variant C

## Why

[spec AC-19, §8 "two or three variants" (default three)](../spec.md), [ADR-0003](../adr/0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look.md).

## What

- A third `PhotoPanelLook`, visibly different from A and B within AC-19's limits, including a different choice of `hidesTabWhileScrolling` from at least one other look so the owner can compare it.
- Register it in `looks.dart`.

## Definition of Done

**Done when:** `photo_panel_look_test.dart` passes for look C (variant `c` maps to it, tab ≤ 200 dp, highlight non-null), and the full behaviour suite of T19 passes with it.

- [ ] test: look registry and interface assertions
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- If the owner settles spec §8 on two variants before this starts, drop this task and remove `c` from `PhotoPanelVariant`.
