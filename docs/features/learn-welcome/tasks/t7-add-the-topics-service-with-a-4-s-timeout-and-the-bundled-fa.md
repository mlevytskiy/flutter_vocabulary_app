---
id: T7
title: "Add the topics service with a 4 s timeout and the bundled fallback"
layer: "app"
deps: ["T6"]
acs: ["AC-03"]
files_hint: ["lib/core/services/learn_topics_service.dart", "lib/core/providers.dart", "test/learn_topics_service_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T7 — Add the topics service with a 4 s timeout and the bundled fallback

## Why

Derives from [AC-03](../spec.md); NFR-01.

## What

One service and its provider.

## Definition of Done

- [ ] `LearnTopicsService.pick(words)` → `List<LearnTopic>` (id, title, description); 4 s timeout; fallback list in the app
- [ ] provider in `lib/core/providers.dart`
- [ ] tests with a mocked client and a fake timer
- [ ] `flutter analyze` clean

## Notes

—
