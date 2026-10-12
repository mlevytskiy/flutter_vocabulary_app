---
id: T6
title: "Define the PhotoPanelLook interface and build look A"
layer: "ui"
deps: ["T3", "T5"]
acs: ["AC-01", "AC-19"]
files_hint: ["lib/features/word_input/photo_panel/looks/photo_panel_look.dart", "lib/features/word_input/photo_panel/looks/look_a.dart", "lib/features/word_input/photo_panel/looks/looks.dart", "test/photo_panel_look_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T6 — Define the PhotoPanelLook interface and build look A

## Why

[spec AC-19](../spec.md), [ADR-0003](../adr/0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look.md), [sad §5 looks/](../sad.md), ux-flows SCR-01, SCR-02, SCR-03.

## What

- `photo_panel_look.dart`: the abstract `PhotoPanelLook` covering only what AC-19 allows: the tab (size ≤ 200 dp asserted, mini previews, count), the small photo and its place in half-open, the large photo and its place in full-open, the expand control and the handle (placed away from the left screen edge), the full-open browsing widget, the row highlight decoration, the placeholder, and `hidesTabWhileScrolling`.
- `look_a.dart`: the first variant, built from the existing theme colours and `Card` / `Material` primitives; full-open browses with a `PageView`.
- `looks.dart`: `lookFor(PhotoPanelVariant)`; variants `b` and `c` return look A until T16 and T17.

## Definition of Done

**Done when:** `photo_panel_look_test.dart` passes: look A is returned for variant `a`, its tab is at most 200 dp tall (the interface assertion fires for a taller test look), it draws at most three mini previews plus the count, and its row highlight is non-null while `WordRowItem` with no highlight is unchanged.

- [ ] test: interface assertion on tab height
- [ ] test: registry mapping
- [ ] test: look A's highlight decoration is non-null
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- No new package; reuses Material widgets and the app theme.
- The interface may still gain a member in T9 or T11; T16 and T17 start after T11 so their looks implement the final interface.
