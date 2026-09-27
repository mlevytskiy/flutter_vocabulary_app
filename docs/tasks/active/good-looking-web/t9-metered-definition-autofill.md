---
id: T9
title: "Meter definition autofill with the page allowance and the all-pages share"
layer: "ports"
deps: ["T6"]
acs: ["AC-16", "AC-17", "AC-18", "AC-18b", "AC-19", "AC-20", "AC-29"]
files_hint: ["vocab-photo-api/src/autofill/meter.ts", "vocab-photo-api/src/define.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/autofill.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T9 — Meter definition autofill with the page allowance and the all-pages share

## Why

[ADR-0003](../../../features/good-looking-web/adr/0003-store-editable-sessions-and-autofill-counters-in-d1.md), [sad §4 metering + §6 flow 3](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-16](../../../features/good-looking-web/spec.md), [AC-17](../../../features/good-looking-web/spec.md), [AC-18](../../../features/good-looking-web/spec.md), [AC-18b](../../../features/good-looking-web/spec.md), [AC-19](../../../features/good-looking-web/spec.md), [AC-20](../../../features/good-looking-web/spec.md), [AC-29](../../../features/good-looking-web/spec.md).

## What

Public route `define for row`: takes one unit from `page_autofill` (limit 50 per UTC day) and one from `all_pages_autofill` (limit 500) with conditional increments; either spent → `autofill_paused` with the next 00:00 UTC. Otherwise reuse the `/define` lookup (cache first), and write the definition only if the cell is still empty (filled cells stay as they are, AC-19); nothing found → `nothing_found` (the unit stays spent, AC-20). The app's `/define` route is unchanged and uncounted (AC-29). Dictionary outages log the "dictionary unavailable" line (spec §7 KPI).

## Definition of Done

- [x] node test: 51st lookup on one page → `autofill_paused` with the resume time (AC-18)
- [x] node test: with the all-pages counter at 500, a page with allowance left gets `autofill_paused`, not `nothing_found` (AC-18b)
- [x] node test: a not-found word spends one unit (AC-20)
- [x] node test: the app's secret-gated `/define` still answers when the page share is spent (AC-29)
- [x] Tests stub Merriam-Webster (no real quota used)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Route: `POST /s/<id>/define` `{rowId}` → `200 {rowId, field: "definition", value, rev}`, in
`src/autofill/routes.ts`; metering in `src/autofill/meter.ts`. Public, `pageWrite: true`.
New codes (fixed here, as the `api` stage was not run): `429 autofill_paused {reason:
"page"|"all_pages", resumesAt}` (next 00:00 UTC; distinct from `rate_limited`),
`422 nothing_found`, `503 dictionary_unavailable`; a filled cell answers `409 conflict` like a
save.

Metering is one D1 batch: `INSERT OR IGNORE` both day rows, raise `all_pages_autofill` only
while both are below their limits, then raise `page_autofill` only if `changes() = 1` (the
previous statement's row count). No read-then-write race and no retry loop; the test fires 55
lookups at once and exactly 50 land. When both are spent the reason is `page`.

Order: a filled, deleted, unknown or wordless row is refused before metering (no unit). After
the unit is taken every outcome keeps it spent — nothing found (AC-20), a cache hit (the
allowance counts page lookups, not dictionary calls), a dictionary outage, and the rare cell
filled meanwhile (the definition is written with T6's "only if still empty" guard). The first
sense ≤ 500 characters is written.

`define.ts`: the cache-then-dictionary part became `lookUpCached()`, shared with the page; the
app's `/define` contract, logging and caching are unchanged and it is never counted (AC-29).
`MW_API_URL` (optional var) overrides the dictionary's base URL; `scripts/test.mjs` starts
`test/mw-stub.mjs` and passes it plus a fake `MW_API_KEY` with `--var` after `--env-file`, so
tests never spend the real quota. `flutter analyze`: same 9 pre-existing infos; the grep's one
hit (`PhotoScaler.instance`) is pre-existing.
