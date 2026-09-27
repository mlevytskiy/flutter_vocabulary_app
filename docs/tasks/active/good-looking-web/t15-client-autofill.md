---
id: T15
title: "Autofill a cell or a whole column, and open a collapsed column"
layer: "ui"
deps: ["T1", "T9", "T13"]
acs: ["AC-16", "AC-17", "AC-18", "AC-18b", "AC-19", "AC-20", "AC-21", "AC-35"]
files_hint: ["vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "L"
status: "done"
---

# T15 — Autofill a cell or a whole column, and open a collapsed column

## Why

[ADR-0007](../../../features/good-looking-web/adr/0007-call-the-translation-endpoint-from-the-partners-browser.md) (after T1's verdict), [sad §4 metering + column autofill](../../../features/good-looking-web/sad.md), [ux-flows US-08–US-10](../../../features/good-looking-web/ux-flows.md). Acceptance criteria: [AC-16](../../../features/good-looking-web/spec.md), [AC-17](../../../features/good-looking-web/spec.md), [AC-18](../../../features/good-looking-web/spec.md), [AC-18b](../../../features/good-looking-web/spec.md), [AC-19](../../../features/good-looking-web/spec.md), [AC-20](../../../features/good-looking-web/spec.md), [AC-21](../../../features/good-looking-web/spec.md), [AC-35](../../../features/good-looking-web/spec.md).

## What

Cell lightning: Translation calls the endpoint from the browser (per T1) and saves like an edit; Definition calls the metered route. Working state while running; "nothing found for this word" beside the cell; "definition autofill paused" with the resume time in local time, translation lightnings still working. Column lightning: empty cells in table order, one by one, each saved as its own request paced at no more than 3 saves per second (sad §4, §8); stops when paused and reports filled / found nothing / stopped after N. The collapsed column's add control opens it locally with empty cells and lightnings.

## Definition of Done

- [x] Manual: definition column with 8 empty and 4 filled → 8 looked up, 4 unchanged, report shown (AC-19)
- [x] Manual with the allowance set to 5 in local D1: stops after 5 and says so (AC-20)
- [x] Manual: paused message names local resume time (AC-18)
- [x] Manual: add Definition on a translation-only page; reload with no text → collapsed again (AC-21)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

If T1 failed, this task waits for the superseding ADR. (T1 passed; ADR-0007 stands.)

No `page.ts` change was needed: `client/page.js` adds the purple bolt buttons (inline SVG, no
image, so the CSP stays `img-src 'self'`). Each Translation and Definition cell gets a bolt;
it is hidden while the cell has text, on a read-only page and without the script. Each open
column's header also gets a bolt.

Cell lightning: it waits for any save of the row still in flight, then checks again that the
cell is still empty and the row has a saved word. Translation calls
`translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=uk&dt=t` from the browser
(CSP `connect-src` allows exactly that host). The segments are joined as in
`translate_response_parser.dart`, and an echo of the word counts as nothing found (T1). The
translation is then saved like an edit. Definition calls `POST /s/<id>/define`. Either way the
answer goes through the same path as a feed change, so a cell typed in meanwhile gets the
AC-11 choice rather than being overwritten. While running, the cell has `working` (a pulse,
static under `prefers-reduced-motion`) and `aria-busy`. Nothing found shows "Nothing found for
this word. Type it yourself, or check the spelling." `autofill_paused` shows "Definition
autofill is paused. It resumes today|tomorrow at <local time>. You can still type the
definition." `resumesAt` is formatted with the browser's time zone. Translation bolts keep
working while definitions are paused.

Column lightning: it collects the fillable cells in table order when pressed and asks for
them one at a time, at least 340 ms apart (≤ 3/s, under the 300-per-minute write limit). A
cell filled or typed in since the run began is skipped. A paused answer or a failure stops
the run. The report is a toast: "<Column> autofill: N filled, M found nothing.", or "The
autofill allowance ran out after N lookups: … Definition autofill resumes …", or "… autofill
stopped after N lookups: … The reason is beside the cell." A second press while a run is going
does nothing.

The collapsed column's "+ Definition" / "+ Translation" button opens the column only in this
page. The CSS now hides the cell's children rather than the cell, so the column appears with
its empty cells and bolts, and focus moves to the header bolt. Nothing is stored, so a reload
collapses it again while it is empty. Once it has text, the server renders it open for
everyone, and a partner's page opens it when the text arrives by poll.

Checked in isolated headless Chrome contexts over CDP against `wrangler dev` with the MW stub
and a stubbed translate endpoint (a temporary script, not committed). Definition column with 8
empty and 4 filled: 8 `/define` requests, 338–345 ms apart. The report said "6 filled, 2 found
nothing"; the 4 filled stayed as they were, and the two "zz" words showed the nothing-found
note. With the page allowance at 45/50 in local D1: the run stopped after 5 lookups and said
"The autofill allowance ran out after 5 lookups: 4 filled, 1 found nothing. Definition
autofill resumes today at 3:00." (Europe/Kyiv, before 03:00 local). The next cell said "It
resumes today at 3:00". Translation bolts still filled "яблуко" and marked an echoed word
nothing found. Translation column: 2 filled, 1 found nothing, 3 endpoint calls. On a
translation-only page, "+ Definition" opened the column for A only, and a reload collapsed it
again. After a definition was filled, B's page opened the column by poll, and A's reload kept
it open. No sideways scroll at 360/1280 px; no script exception or CSP report.

Bug found by that check and fixed: the column run's first pause was `sleep(0 + 340 - now)`.
setTimeout turns a large negative delay into a huge 32-bit one, so the run never started. It
is now clamped to 0.

`npm run typecheck` is clean; `npm test` gives 51 pass, 1 skipped. `flutter analyze` still
reports the 9 infos it had before, and the grep finds only the existing
`PhotoScaler.instance`.
