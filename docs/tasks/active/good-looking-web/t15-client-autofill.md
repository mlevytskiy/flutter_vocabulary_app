---
id: T15
title: "Autofill a cell or a whole column, and open a collapsed column"
layer: "ui"
deps: ["T1", "T9", "T13"]
acs: ["AC-16", "AC-17", "AC-18", "AC-18b", "AC-19", "AC-20", "AC-21", "AC-35"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T15 — Autofill a cell or a whole column, and open a collapsed column

## Why

[ADR-0007](../../../features/good-looking-web/adr/0007-call-the-translation-endpoint-from-the-partners-browser.md) (after T1's verdict), [sad §4 metering + column autofill](../../../features/good-looking-web/sad.md), [ux-flows US-08–US-10](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-16](../../../features/good-looking-web/spec.md), [AC-17](../../../features/good-looking-web/spec.md), [AC-18](../../../features/good-looking-web/spec.md), [AC-18b](../../../features/good-looking-web/spec.md), [AC-19](../../../features/good-looking-web/spec.md), [AC-20](../../../features/good-looking-web/spec.md), [AC-21](../../../features/good-looking-web/spec.md), [AC-35](../../../features/good-looking-web/spec.md).

## What

Cell lightning: Translation calls the endpoint from the browser (per T1) and saves like an edit; Definition calls the metered route. Working state while running; "nothing found for this word" beside the cell; "definition autofill paused" with the resume time in local time, translation lightnings still working. Column lightning: empty cells in table order, one by one, each saved as its own request paced at no more than 3 saves per second (sad §4, §8); stops when paused and reports filled / found nothing / stopped after N. The collapsed column's add control opens it locally with empty cells and lightnings.

## Definition of Done

- [ ] Manual: definition column with 8 empty and 4 filled → 8 looked up, 4 unchanged, report shown (AC-19)
- [ ] Manual with the allowance set to 5 in local D1: stops after 5 and says so (AC-20)
- [ ] Manual: paused message names local resume time (AC-18)
- [ ] Manual: add Definition on a translation-only page; reload with no text → collapsed again (AC-21)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

If T1 failed, this task waits for the superseding ADR.
