---
id: T20
title: "Keep the picked look and remove the others, the variant choice and its key"
layer: "wiring"
deps: ["T19"]
acs: ["AC-20"]
files_hint: ["lib/features/word_input/photo_panel/looks", "lib/core/providers.dart", "lib/core/providers.g.dart", "lib/features/settings/settings_screen.dart", "test/settings_screen_test.dart", "test/photo_panel_test.dart", "test/photo_panel_look_test.dart", "CLAUDE.md", "docs/architecture.md", "docs/roadmap.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T20 — Keep the picked look and remove the others, the variant choice and its key

## Why

[spec AC-20](../spec.md), [sad §7 release build and §11 "losing looks outlive the pick"](../sad.md), [ADR-0003](../adr/0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look.md).

## What

- Delete the two losing look files and `looks.dart`; rename nothing else in the picked look (cut-and-paste, CLAUDE.md rule 3).
- Remove `photoPanelVariantProvider`, its key and the Settings choice; the `photo_panel_test.dart` loop collapses to the one look.
- Docs: CLAUDE.md rule 3 parenthetical, `docs/architecture.md`, roadmap #23 status.

## Definition of Done

**Done when:** Only the picked look remains and `PhotoPanel` uses it directly; `grep -rn "photo_panel_variant\|PhotoPanelVariant" lib test` is empty; the Settings choice is gone and `settings_screen_test.dart` is back to its pre-feature cases; CLAUDE.md rule 3 no longer lists the Settings choice; `docs/architecture.md` names `photo_panel/` and the gesture exclusion channel; `tool/test.sh changed` is green.

- [ ] test: the grep in the DoD
- [ ] test: `tool/test.sh changed`
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- **Blocked on the owner's design pick** on the phone (spec AC-20, §7 "Design pick").
- The release gate after this is the owner's device pass (`device-pass.md`) on the picked look.
