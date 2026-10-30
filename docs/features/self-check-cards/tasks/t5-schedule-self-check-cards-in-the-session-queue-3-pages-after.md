---
id: T5
title: "Schedule self-check cards in the session queue: 3 pages after a flag, no limit, re-flag gets a new card"
layer: "domain"
deps: ["T4"]
acs: ["AC-02"]
files_hint: ["lib/features/learn/session/ladder_queue.dart", "lib/features/learn/session/learning_session_notifier.dart", "test/learn_session_ladder_queue_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T5 — Schedule self-check cards in the session queue: 3 pages after a flag, no limit, re-flag gets a new card

## Why

Derives from [AC-02](../spec.md); see [spec](../spec.md).

## What

See the files.

## Definition of Done

- [ ] pure queue tests with a seeded Random: card 3 pages after the flag; fewer pages left → right after the last exercise page; never next to the same word's page while another page is pending; every flag gets one card; a word flagged after its card gets another; the last rating wins; page counter totals include cards
- [ ] `flutter analyze` clean

## Notes

needs [learn-welcome](../../learn-welcome/tasks.json) T2 (`lastCheckSide`), T3 (`self_check.dart`) and T11 (`self_check_card.dart`) first (ADR-0006 there).
