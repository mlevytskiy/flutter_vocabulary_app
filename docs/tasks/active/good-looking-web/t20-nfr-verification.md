---
id: T20
title: "Run the concurrency, limits and performance checks from sad \u00a710"
layer: "tests"
deps: ["T10", "T14", "T15", "T16"]
acs: ["AC-03", "AC-11", "AC-12", "AC-35"]
files_hint: ["vocab-photo-api/test/concurrency.test.mjs", "vocab-photo-api/test/limits.test.mjs", "docs/features/good-looking-web/verification.md"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T20 — Run the concurrency, limits and performance checks from sad §10

## Why

[sad §10 QG-1…QG-3](../../../features/good-looking-web/sad.md), spec §6. Acceptance criteria: [AC-03](../../../features/good-looking-web/spec.md), [AC-11](../../../features/good-looking-web/spec.md), [AC-12](../../../features/good-looking-web/spec.md), [AC-35](../../../features/good-looking-web/spec.md).

## What

node test: 3 clients × 100 edits on the same and different cells — every edit landed or got a conflict (0 lost). Limit + 1 tests for rows, field length, session size, 10 photos. Lighthouse mobile run on a 100-row session (first render p95 ≤ 2.0 s); visual check at 360/390/414 px; two-browser 20-edit timing. Results written to `verification.md`.

## Definition of Done

- [ ] Concurrency test green with 0 lost edits
- [ ] Each limit + 1 refused with its code
- [ ] `verification.md` records Lighthouse, width checks and edit-propagation timings against spec §6 targets
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
