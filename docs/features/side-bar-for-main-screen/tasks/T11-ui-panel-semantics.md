---
id: T11
title: "Make every panel state reachable and closable with a screen reader"
layer: "ui"
deps: ["T9"]
acs: ["AC-18"]
files_hint: ["lib/features/word_input/photo_panel/photo_panel.dart", "lib/features/word_input/photo_panel/looks/photo_panel_look.dart", "test/photo_panel_semantics_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T11 — Make every panel state reachable and closable with a screen reader

## Why

[spec AC-18](../spec.md), [sad §8 Accessibility](../sad.md), sad §6 Flow 9.

## What

- `Semantics` wrappers in `PhotoPanel` (the behaviour owns the labels and actions, not the look), with the look supplying only the widgets.
- A labelled close button in half-open and a labelled control back to half-open in full-open, added to the interface if look A does not yet expose them.

## Definition of Done

**Done when:** `photo_panel_semantics_test.dart` passes with `tester.ensureSemantics()`: the tab is one node labelled "Session photos, N" whose tap action opens half-open (ignored while busy), each small photo is a selectable button, labelled expand, close and back-to-half-open buttons exist, and every state is reached and left without a drag.

- [ ] test: semantics finders by label and `SemanticsAction.tap`
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Last change to `PhotoPanelLook`; T16 and T17 start after this.
