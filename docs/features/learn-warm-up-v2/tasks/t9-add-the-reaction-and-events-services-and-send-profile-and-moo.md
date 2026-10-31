---
id: T9
title: "Add the reaction and events services and send profile and mood with the topic pick"
layer: "app"
deps: ["T3", "T4", "T6"]
acs: ["AC-05", "AC-12", "AC-13", "AC-17"]
files_hint: ["lib/core/services/warm_up_reaction_service.dart", "lib/core/services/learn_events_service.dart", "lib/core/services/learn_topics_service.dart", "lib/core/providers.dart", "test/warm_up_services_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T9 — Add the reaction and events services and send profile and mood with the topic pick

## Why

Derives from [AC-05](../spec.md), [AC-12](../spec.md), [AC-13](../spec.md), [AC-17](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] WarmUpReactionService: one try, 2 s, fixed line (six lines, random) on failure, late or empty
- [ ] LearnEventsService: fire-and-forget, never throws
- [ ] LearnTopicsService sends profile + mood, reads situation lines, timeout counted from a given start
- [ ] providers added
- [ ] tests with mocked clients and fake timers
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
