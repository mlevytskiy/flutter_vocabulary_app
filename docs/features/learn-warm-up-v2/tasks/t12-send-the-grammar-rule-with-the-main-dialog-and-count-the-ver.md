---
id: T12
title: "Send the grammar rule with the main dialog and count the verdicts"
layer: "app"
deps: ["T5", "T10"]
acs: ["AC-09", "AC-10"]
files_hint: ["lib/features/learn/talk/talk_notifier.dart", "lib/core/services/talk_api_service.dart", "lib/features/learn/flow/learn_flow_notifier.dart", "test/learn_session_talk_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T12 — Send the grammar rule with the main dialog and count the verdicts

## Why

Derives from [AC-09](../spec.md), [AC-10](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] Talk notifier sends the rule on start and every reply
- [ ] collects grammarVerdict for learner lines
- [ ] right/wrong counted, unsure left out
- [ ] boxes and word results unchanged
- [ ] the counts reach LearnFlowResults
- [ ] notifier tests
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
