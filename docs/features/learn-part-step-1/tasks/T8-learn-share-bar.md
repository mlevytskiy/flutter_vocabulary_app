---
id: T8
title: "Add LearnShareBar that fits Learn and Share by measuring the space"
layer: "ui"
deps: []
acs: ["AC-01", "AC-11", "AC-11b", "AC-12"]
files_hint: ["lib/features/words_table/widgets/learn_share_bar.dart", "test/learn_share_bar_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T8 — Add LearnShareBar that fits Learn and Share by measuring the space

## Why

[screens.md](../screens.md) SCR-02 (normal bar, compact bar, icon-only bar, icon-only long press) and its New components row; [sad §4](../sad.md) "The narrow Words top bar is fitted by measuring"; [sad §10](../sad.md) QG-3; spec §6 "Narrow top bar", "Tap target".

## What

- `lib/features/words_table/widgets/learn_share_bar.dart` — takes `onLearn`, `onShare` and the title; uses `LayoutBuilder` + `TextPainter` at `MediaQuery.textScalerOf` to choose the layout; Learn is `ElevatedButton.icon` with `Icons.school` and "Learn", styled like Share; order back arrow, Learn, "Words", Share.
- `test/learn_share_bar_test.dart`.

## Definition of Done

**Done when:** `LearnShareBar` measures the available width at the current text scale and picks normal (Share exactly as today, Learn matching), compact (smaller padding, labels kept) or icon-only (`Tooltip` "Learn"/"Share"), with no fixed width breakpoints; widget tests at 360 dp/100 %, 320 dp/100 % and 320 dp/130 % show labels at 360 dp, no `RenderFlex` overflow, the title "Words" whole and each button ≥ 48 × 48 dp.

- [ ] at a width where everything fits: Share's padding, icon, label and style equal today's (`Padding(right: 16)`, same `ElevatedButton.icon`) — AC-12
- [ ] at 360 dp/100 %: labels shown
- [ ] at 320 dp/100 % and 320 dp/130 %: no overflow exception, "Words" not ellipsised, each button's size ≥ 48 × 48
- [ ] in the icon-only layout a long press shows "Learn" / "Share" (AC-11b)
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Independent of every other task — a parallel branch from the start.
- **Rule 3:** cut-and-paste Share's current button code into the widget; do not restyle it. The compact and icon-only layouts are the approved visible change (sad §2).
- How the bar sits in `AppBar` (title vs actions vs `leading`) is decided here so T9 only plugs it in.
