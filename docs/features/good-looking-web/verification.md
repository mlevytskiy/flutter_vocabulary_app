---
status: living
updated_at: "2026-09-28"
---

# Verification — good-looking-web (T20)

Results of the sad §10 checks (QG-1…QG-3) against the spec §6 targets. Worker tests run with
`npm test` in `vocab-photo-api/` (local `wrangler dev`, sad §10 harness); the long AC-35 run
with `npm run test:long`. "Local" means `wrangler dev` on a MacBook, not the deployed Worker.

## Summary

| spec §6 target | Result | Where |
|---|---|---|
| Lost edits under concurrent editing = 0 | **0 lost** — 300 edits landed, 208–210 conflicts, each resolved (2 runs) | `test/concurrency.test.mjs` |
| Other partners' edits on an open page ≤ 10 s | **max 5.0 s**, p95 4.3–5.0 s over 20 edits (local, 5 s poll) | `test/concurrency.test.mjs` |
| ≤ 500 rows, ≤ 500 chars/field, ≤ 256 KB/session | each limit + 1 refused with its code, publish and page | see [Limits](#limits-qg-2) |
| Photos per published session ≤ 10 | 11th refused by the Worker; the app declares 10 and names the one left out | `test/limits.test.mjs`, `test/session_publish_service_test.dart`, `test/words_table_test.dart` |
| 50 lookups/page/day; pages stop at 500/day | 51st and 501st paused | `test/autofill.test.mjs` (T9) |
| Two partners, 15 min, one column autofill: never turned away (AC-35) | see [AC-35](#ac-35-15-minute-two-partner-session) | `test/rows.test.mjs` |
| First render p95, 100 rows, phone on 4G ≤ 2.0 s | **LCP 974–1063 ms** (5 runs, local) | [Lighthouse](#lighthouse-qg-3) |
| No page-level sideways scroll at 360 px | none at 360 / 390 / 414 px; only the table scrolls | [Widths](#phone-widths-qg-3-ac-03) |
| Cell save p95 ≤ 1.0 s; single-cell autofill p95 ≤ 3.0 s | **not yet measured** — Cloudflare analytics after the deploy | README "KPIs" |
| Publish with 3 photos on 4G: dialog ≤ 3 s, photos ≤ 30 s | **not yet measured** — manual, on device, 10 runs | — |

## Concurrency (QG-1, AC-11, AC-12)

`3 clients × 100 edits on shared and own cells`. Each client saves one cell at a time, the way
the page does, from the revision it last saw: two cells of one row are shared by all three
clients, and each client also has a cell of its own row. A conflict is resolved by keeping the
client's value — a save from the revision the conflict named — until it lands. Checked:

- every answer is `200` or `409 conflict`; all 300 edits land;
- each landed save has its own revision; the session revision equals the number of landed saves;
- per cell, the landed saves form one chain (each started from the previous save's revision), so
  no save overwrote a value its client never saw — the definition of a lost edit;
- every conflict named a value that really was saved, at the revision it was saved at;
- cells only one client edits never conflict (AC-12);
- D1 and the change feed from revision 0 both hold the last save of every cell.

Runs on 2026-09-28: 300 landed / 210 conflicts; 300 landed / 208 conflicts. 0 lost.

**Edit propagation.** A writer saves 20 edits about 0.7 s apart; a reader polls
`/changes` every 5 s (`POLL_MS` in `src/session/client/page.js`). An edit counts as seen at the
first poll whose revision covers it. Runs: p95 4337 ms / max 5004 ms; p95 5004 ms / max
5011 ms. The bound is the poll interval, so the deployed Worker adds only its round trip.
The two-browser check (real pages, 20 edits by hand) is still to do on the deployed page.

## Limits (QG-2)

Each limit, at the limit (accepted) and at limit + 1 (refused):

| Limit | Publish (`POST /sessions`) | Page (`/s/<id>/…`) |
|---|---|---|
| 500 rows | 500 stored; 501 → `400` "At most 500 entries" (`limits`) | 500th add `200`; 501st → `422 rows_full`, `limit: 500` (`rows`) |
| 500 characters per field | 500 stored in each of the three; 501 in word / translation → `400`; in definition → `400` naming the word (`limits`) | save: 501 → `422 field_too_long`, `overflow: 1` (`edit`); add: 500 `200`, 501 → `422 field_too_long` (`limits`) |
| 256 KB per session | body over 256 KB → `413` (`limits`) | save: +1 byte → `422 list_full` (`edit`); add: +1 byte → `422 list_full` (`limits`) |
| 10 photos | 10 declared; 11 → `400` "at most 10 sources" (`limits`, `publish`) | — |
| 300 page writes / min / IP | — | 301st → `429 rate_limited`, reads never (`rows`) |
| 50 lookups / page / day; 500 all pages | — | 51st / 501st → `429 autofill_paused` (`autofill`) |
| page request body | — | over 16 KB → `413` before D1 (`limits`) |

Photos of a session published without photos answer "gone" for any guessed id (AC-24,
`publish.test.mjs`).

## AC-35, 15-minute two-partner session

`npm run test:long`: two partners on one address for 15 minutes, one filling a 500-cell column at
3 saves a second, the other editing at a normal pace. The 65-second busiest stretch runs in every
`npm test` and saw only `200`s.

Result 2026-09-28: green in 902 s — more than 900 writes, every answer `200`, no `429`.

## Lighthouse (QG-3)

Lighthouse 13.5.0, mobile form factor, simulated throttling (150 ms RTT, 1.6 Mbps, 4× CPU),
against a 100-row `both` session (every third row with a definition) on local `wrangler dev`,
Chrome headless, 5 runs:

| Run | Perf score | FCP | LCP | Speed Index | TBT | CLS |
|---|---|---|---|---|---|---|
| 1 | 100 | 908 ms | 976 ms | 1201 ms | 86 ms | 0.025 |
| 2 | 100 | 1063 ms | 1063 ms | 1063 ms | 0 ms | 0 |
| 3 | 100 | 907 ms | 975 ms | 907 ms | 87 ms | 0.025 |
| 4 | 100 | 907 ms | 974 ms | 907 ms | 84 ms | 0.025 |
| 5 | 100 | 909 ms | 977 ms | 909 ms | 86 ms | 0.025 |

Worst LCP 1063 ms against the 2.0 s target. The page is server-rendered HTML with inline CSS
and one cached script, so the throttled network dominates; the deployed Worker's edge answer
should not change the picture. Rerun against the deployed link:
`npx lighthouse@13.5.0 <url> --only-categories=performance --form-factor=mobile`.

## Phone widths (QG-3, AC-03)

The same 100-row page in headless Chrome with mobile emulation (DPR 2), measured through the
DevTools protocol:

| Width | Document scroll width | Page sideways scroll | Table scroller | Table content / visible |
|---|---|---|---|---|
| 360 px | 360 | no | `div.table-scroll` | 592 / 336 px |
| 390 px | 390 | no | `div.table-scroll` | 610 / 366 px |
| 414 px | 414 | no | `div.table-scroll` | 610 / 390 px |

No element outside the table reaches past the viewport at any width. A look at the page on a
real phone is still worth doing once it is deployed.

## Still open

The Worker was deployed on 2026-09-28 (version `b4149c70`); the items below can now run
against `https://vocab-photo-api.vocabphotoapi.workers.dev`.

- Cell save and autofill p95 from Cloudflare analytics — needs traffic on the deployed Worker.
- Lighthouse and the width checks rerun against a deployed 100-row link.
- Publish with 3 photos on 4G, 10 runs on device (dialog ≤ 3 s, photos ≤ 30 s).
- Two real browsers on one deployed session, 20 edits timed.
