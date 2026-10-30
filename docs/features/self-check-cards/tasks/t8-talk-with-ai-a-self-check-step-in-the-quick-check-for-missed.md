---
id: T8
title: "Talk with AI: a self-check step in the quick check for missed and hinted words; talk scoring through the ratings"
layer: "ui"
deps: ["T3", "T6"]
acs: ["AC-11"]
files_hint: ["lib/features/learn/talk/talk_rules.dart", "lib/features/learn/talk/talk_quiz.dart", "lib/features/learn/talk/talk_quiz_card.dart", "lib/features/learn/talk/talk_notifier.dart", "test/talk_quiz_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T8 — Talk with AI: a self-check step in the quick check for missed and hinted words; talk scoring through the ratings

## Why

Derives from [AC-11](../spec.md); see [spec](../spec.md).

## What

See the files.

## Definition of Done

- [ ] scoreTalk returns flags (mistake / hint / clean / unused) instead of missed; the quick check adds a self-check card per flagged word (same widget as T6, chat-card size); ratings go to applySession; talk ended before the check → flagged words keep their box; tests in talk_quiz_test and learn_session_talk tests
- [ ] `flutter analyze` clean

## Notes

needs [learn-welcome](../../learn-welcome/tasks.json) T2 (`lastCheckSide`), T3 (`self_check.dart`) and T11 (`self_check_card.dart`) first (ADR-0006 there).
