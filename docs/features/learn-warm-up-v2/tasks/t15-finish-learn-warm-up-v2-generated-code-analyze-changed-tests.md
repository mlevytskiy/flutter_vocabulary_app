---
id: T15
title: "Finish learn-warm-up-v2: generated code, analyze, changed tests, grep check, deploy order, device check list"
layer: "docs"
deps: ["T2", "T11", "T13", "T14"]
acs: ["AC-12", "AC-15"]
files_hint: ["docs/folder-layout.md", "docs/architecture-features.md", "docs/features/learn-warm-up-v2/device-check.md"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T15 — Finish learn-warm-up-v2: generated code, analyze, changed tests, grep check, deploy order, device check list

## Why

Derives from [AC-12](../spec.md), [AC-15](../spec.md). Design: [sad.md](../sad.md).

## Definition of Done

- [ ] build_runner, flutter analyze, tool/test.sh -q changed and the Worker tests green
- [ ] grep for Navigator.push clean
- [ ] folder-layout.md and architecture-features.md updated
- [ ] device-check.md written
- [ ] note: deploy the Worker before the app
- [ ] `flutter analyze` clean; `tool/test.sh -q changed` green (Worker: its Node tests)

## Notes

—
