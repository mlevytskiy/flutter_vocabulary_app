---
id: T20
title: "Run the concurrency, limits and performance checks from sad \u00a710"
layer: "tests"
deps: ["T10", "T14", "T15", "T16"]
acs: ["AC-03", "AC-11", "AC-12", "AC-35"]
files_hint: ["vocab-photo-api/test/concurrency.test.mjs", "vocab-photo-api/test/limits.test.mjs", "docs/features/good-looking-web/verification.md"]
owner: "Maksym"
estimate: "M"
status: "review"
---

# T20 — Run the concurrency, limits and performance checks from sad §10

## Why

[sad §10 QG-1…QG-3](../../../features/good-looking-web/sad.md), spec §6. Acceptance criteria: [AC-03](../../../features/good-looking-web/spec.md), [AC-11](../../../features/good-looking-web/spec.md), [AC-12](../../../features/good-looking-web/spec.md), [AC-35](../../../features/good-looking-web/spec.md).

## What

node test: 3 clients × 100 edits on the same and different cells — every edit landed or got a conflict (0 lost). Limit + 1 tests for rows, field length, session size, 10 photos. Lighthouse mobile run on a 100-row session (first render p95 ≤ 2.0 s); visual check at 360/390/414 px; two-browser 20-edit timing. Results written to `verification.md`.

## Definition of Done

- [x] Concurrency test green with 0 lost edits
- [x] Each limit + 1 refused with its code
- [x] `verification.md` records Lighthouse, width checks and edit-propagation timings against spec §6 targets
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

2026-09-28: `test/concurrency.test.mjs` (3 × 100 edits: 300 landed, ~210 conflicts, 0 lost;
20-edit propagation max 5.0 s at the page's 5 s poll) and `test/limits.test.mjs` (publish and
add-row limits + 1; the page save limits were already in `edit`/`rows`). `npm test` 62 pass,
`npm run test:long` green (AC-35). Lighthouse and the 360/390/414 px checks ran against local
`wrangler dev` (LCP ≤ 1.07 s, no page sideways scroll). Left for after the T21 deploy, in
`verification.md` "Still open": save/autofill p95 from Cloudflare analytics, the 3-photo publish
timing on device, and the two-real-browser 20-edit timing.
