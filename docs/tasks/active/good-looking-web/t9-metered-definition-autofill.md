---
id: T9
title: "Meter definition autofill with the page allowance and the all-pages share"
layer: "ports"
deps: ["T6"]
acs: ["AC-16", "AC-17", "AC-18", "AC-18b", "AC-19", "AC-20", "AC-29"]
files_hint: ["vocab-photo-api/src/autofill/meter.ts", "vocab-photo-api/src/define.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/autofill.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T9 — Meter definition autofill with the page allowance and the all-pages share

## Why

[ADR-0003](../../../features/good-looking-web/adr/0003-store-editable-sessions-and-autofill-counters-in-d1.md), [sad §4 metering + §6 flow 3](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-16](../../../features/good-looking-web/spec.md), [AC-17](../../../features/good-looking-web/spec.md), [AC-18](../../../features/good-looking-web/spec.md), [AC-18b](../../../features/good-looking-web/spec.md), [AC-19](../../../features/good-looking-web/spec.md), [AC-20](../../../features/good-looking-web/spec.md), [AC-29](../../../features/good-looking-web/spec.md).

## What

Public route `define for row`: takes one unit from `page_autofill` (limit 50 per UTC day) and one from `all_pages_autofill` (limit 500) with conditional increments; either spent → `autofill_paused` with the next 00:00 UTC. Otherwise reuse the `/define` lookup (cache first), and write the definition only if the cell is still empty (filled cells stay as they are, AC-19); nothing found → `nothing_found` (the unit stays spent, AC-20). The app's `/define` route is unchanged and uncounted (AC-29). Dictionary outages log the "dictionary unavailable" line (spec §7 KPI).

## Definition of Done

- [ ] node test: 51st lookup on one page → `autofill_paused` with the resume time (AC-18)
- [ ] node test: with the all-pages counter at 500, a page with allowance left gets `autofill_paused`, not `nothing_found` (AC-18b)
- [ ] node test: a not-found word spends one unit (AC-20)
- [ ] node test: the app's secret-gated `/define` still answers when the page share is spent (AC-29)
- [ ] Tests stub Merriam-Webster (no real quota used)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
