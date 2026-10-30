---
id: T10
title: "Add the LearnFlowNotifier: phases, per-card save, story start and reuse, leave"
layer: "app"
deps: ["T3", "T4", "T5", "T7"]
acs: ["AC-01", "AC-08", "AC-09", "AC-13", "AC-16"]
files_hint: ["lib/features/learn/flow/learn_flow_notifier.dart", "lib/core/providers.dart", "test/learn_flow_notifier_test.dart"]
owner: "implementer agent"
estimate: "L"
status: "done"
---

# T10 — Add the LearnFlowNotifier: phases, per-card save, story start and reuse, leave

## Why

Derives from [AC-01](../spec.md), [AC-08](../spec.md), [AC-09](../spec.md), [AC-13](../spec.md), [AC-16](../spec.md); see [ADR-0001](../adr/0001-run-the-learn-flow-in-one-notifier-over-one-pager.md).

## What

New notifier (generated code), a provider for the dialog setup.

## Definition of Done

- [ ] phases warmUp → cards → dialog → results; topic and mode kept in state
- [ ] each rating: `rateBox` + `nextSide` → one `CollectionStore.update` ([ADR-0004](../adr/0004-save-each-card-rating-at-once.md))
- [ ] on entering cards: per story group reuse a finished `StoryRun` whose row-id set equals the group's, else `StoryRunTracker.startFor` with a `WordGroup` built from the group; the talk mission picture is requested too
- [ ] the dialog setup (topic, maxReplies, dialogWords) handed to the Talk notifier by provider
- [ ] leave: stories keep running into Story runs; nothing else saved
- [ ] tests in `test/learn_flow_notifier_test.dart`
- [ ] `flutter analyze` clean

## Notes

L but one cohesive file; split the story start/reuse part into its own helper if it passes ~400 lines.
