---
id: T16
title: "Build design variant B"
layer: "ui"
deps: ["T11"]
acs: ["AC-19"]
files_hint: ["lib/features/word_input/photo_panel/looks/look_b.dart", "lib/features/word_input/photo_panel/looks/looks.dart", "test/photo_panel_look_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T16 — Build design variant B

## Why

[spec AC-19, §8 "two or three variants" (default three)](../spec.md), [ADR-0003](../adr/0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look.md), ux-flows SCR-01 to SCR-03.

## What

- A second `PhotoPanelLook` that differs from A only where AC-19 allows: the look (tab, small and large photos, row highlight), the full-open browsing (for example a vertical scrolling list instead of a pager), and `hidesTabWhileScrolling`.
- Register it in `looks.dart`.

## Definition of Done

**Done when:** `photo_panel_look_test.dart` passes for look B (variant `b` maps to it, tab ≤ 200 dp, highlight non-null), and the full behaviour suite of T19 passes with it.

- [ ] test: look registry and interface assertions
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Reuses Material primitives and theme colours; no new package or asset.
- Shares `looks.dart` with T17, so they run one after the other.
