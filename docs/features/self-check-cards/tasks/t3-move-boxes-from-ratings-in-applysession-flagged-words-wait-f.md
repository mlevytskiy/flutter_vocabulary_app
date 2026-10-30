---
id: T3
title: "Move boxes from ratings in applySession: flagged words wait for their card, unrated flagged words keep their box"
layer: "domain"
deps: ["T1"]
acs: ["AC-01", "AC-08", "AC-09", "AC-10"]
files_hint: ["lib/features/learn/session/leitner.dart", "lib/features/learn/session/session_result.dart", "test/learn_session_leitner_test.dart", "lib/core/models/word_box.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T3 — Move boxes from ratings in applySession: flagged words wait for their card, unrated flagged words keep their box

## Why

Derives from [AC-01](../spec.md), [AC-08](../spec.md), [AC-09](../spec.md), [AC-10](../spec.md); see [spec](../spec.md).

## What

See the files.

## Definition of Done

- [ ] applySession takes each word's outcome plus an optional rating; a mistake alone no longer sends a word to box 1; clean words as before; flagged + no rating → box and dueAt unchanged; SessionMove carries the rating; existing leitner tests updated to the new rules, talk 'unused' unchanged; uses rateBox from learn-welcome's self_check.dart with afterMistake for the guard
- [ ] `flutter analyze` clean

## Notes

needs [learn-welcome](../../learn-welcome/tasks.json) T2 (`lastCheckSide`), T3 (`self_check.dart`) and T11 (`self_check_card.dart`) first (ADR-0006 there).
