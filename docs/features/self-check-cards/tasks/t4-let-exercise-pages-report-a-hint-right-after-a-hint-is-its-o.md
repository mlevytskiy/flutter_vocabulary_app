---
id: T4
title: "Let exercise pages report a hint: right after a hint is its own result, not a clean right"
layer: "domain"
deps: ["T1"]
acs: ["AC-01"]
files_hint: ["lib/features/learn/session/exercise_page.dart", "lib/features/learn/kit/typed_answer_field.dart", "test/learn_kit_typed_answer_field_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T4 — Let exercise pages report a hint: right after a hint is its own result, not a clean right

## Why

Derives from [AC-01](../spec.md); see [spec](../spec.md).

## What

See the files.

## Definition of Done

- [ ] inventory of exercises with a hint written in this task file; PageAnswer results carry right / wrong / hinted per row id (old bool callers still compile); the typed answer field's second-try right after the 'Starts with' line reports hinted; tests for the typed field and one board page; 'Show answer' reports wrong
- [ ] `flutter analyze` clean

## Notes

needs [learn-welcome](../../learn-welcome/tasks.json) T2 (`lastCheckSide`), T3 (`self_check.dart`) and T11 (`self_check_card.dart`) first (ADR-0006 there).
