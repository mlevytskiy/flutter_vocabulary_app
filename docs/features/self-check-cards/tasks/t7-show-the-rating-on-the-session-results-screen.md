---
id: T7
title: "Show the rating on the session results screen"
layer: "ui"
deps: ["T3", "T6"]
acs: ["AC-10"]
files_hint: ["lib/features/learn/session/session_results_screen.dart", "test/learn_session_results_screen_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T7 — Show the rating on the session results screen

## Why

Derives from [AC-10](../spec.md); see [spec](../spec.md).

## What

See the files.

## Definition of Done

- [ ] each rated word's row shows its rating beside the box move ('Hard · box 3 → 2'); unrated flagged word says 'not checked, box kept'; widget test
- [ ] `flutter analyze` clean

## Notes

needs [learn-welcome](../../learn-welcome/tasks.json) T2 (`lastCheckSide`), T3 (`self_check.dart`) and T11 (`self_check_card.dart`) first (ADR-0006 there).
