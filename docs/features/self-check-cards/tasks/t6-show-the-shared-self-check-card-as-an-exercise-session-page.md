---
id: T6
title: "Show the shared self-check card as an exercise-session page"
layer: "ui"
deps: ["T5"]
acs: ["AC-03", "AC-04"]
files_hint: ["lib/features/learn/session/learning_session_screen.dart", "lib/features/learn/session/page_registry.dart", "test/learn_self_check_page_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T6 — Show the shared self-check card as an exercise-session page

## Why

Derives from [AC-03](../spec.md), [AC-04](../spec.md); see [spec](../spec.md).

## What

See the files.

## Definition of Done

- [ ] the session plays a due check card as a page in the learn page frame (no Check, no verdict bar) using learn-welcome's SelfCheckCard; its rating reaches the session notifier; widget test
- [ ] `flutter analyze` clean

## Notes

needs [learn-welcome](../../learn-welcome/tasks.json) T2 (`lastCheckSide`), T3 (`self_check.dart`) and T11 (`self_check_card.dart`) first (ADR-0006 there).
