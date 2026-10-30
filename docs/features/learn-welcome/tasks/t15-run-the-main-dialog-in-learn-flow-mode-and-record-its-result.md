---
id: T15
title: "Run the main dialog in learn-flow mode and record its results without moving boxes"
layer: "ui"
deps: ["T8", "T10"]
acs: ["AC-13", "AC-14"]
files_hint: ["lib/features/learn/talk/talk_notifier.dart", "lib/features/learn/talk/talk_screen.dart", "lib/router/routes.dart", "test/learn_flow_talk_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T15 — Run the main dialog in learn-flow mode and record its results without moving boxes

## Why

Derives from [AC-13](../spec.md), [AC-14](../spec.md); owner A18, proxy Q2, Q7, Q15.

## What

Talk notifier/screen hooks and the route.

## Definition of Done

- [ ] `TalkRoute` gets a learn-flow flag; `TalkNotifier` reads the setup from the flow provider and sends topic/maxReplies/words
- [ ] on end, per-word results (used / after hint / missed / unused) go to the flow and `WordResult`; no `applySession` box move
- [ ] a refused talk (daily limit) returns to the flow with "Daily talk limit reached"
- [ ] tests in `test/learn_flow_talk_test.dart`
- [ ] `flutter analyze` clean

## Notes

The quick check's self-check card for missed/hinted words is self-check-cards T8.
