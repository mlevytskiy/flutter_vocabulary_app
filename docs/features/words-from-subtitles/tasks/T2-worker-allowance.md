---
id: T2
title: "Take one subtitle import from the address window and the daily cap, and clean up old windows"
layer: "infra"
deps: ["T1"]
acs: ["AC-14"]
files_hint: ["vocab-photo-api/src/subtitles/allowance.ts", "vocab-photo-api/src/session/cleanup.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/test/subtitles-allowance.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T2 — Take one subtitle import from the address window and the daily cap, and clean up old windows

## Why

[ADR-0003](../adr/0003-count-subtitle-imports-per-address-and-per-day-in-d1.md), [data-model.md](../data-model.md) (the take batch and the cleanup rule), [sad §8](../sad.md) Address privacy.

## What

- `src/subtitles/allowance.ts`: `SUBTITLE_WINDOW_LIMIT = 10`, `SUBTITLE_DAY_LIMIT = 20`, window start floored to 10 minutes, SHA-256 hex of `cf-connecting-ip`, and the four-statement batch from data-model.md. Reuse `utcDay()` from `src/autofill/meter.ts` rather than copying it.
- Return `taken`, or `refused` with the reason (`window` / `day`), which is logged and never sent to the client.
- `src/session/cleanup.ts`: add the `DELETE FROM subtitle_imports WHERE window_start < <current window start>` to the daily run and log its count; `scheduled` in `src/index.ts` already calls the cleanup.

## Definition of Done

**Done when:** `takeSubtitleImport` takes a unit from both counters or neither (the 11th take in a window and the 21st of a day are refused, and neither counter moves on a refusal), stores only the SHA-256 hex of the address, and the daily cleanup deletes every window before the current one; covered by tests.

- [ ] 10 takes succeed and the 11th is refused in the same window, with both counters at 10
- [ ] with the day row seeded at 20, a fresh address is refused and its window stays at 0
- [ ] the stored `ip_hash` is 64 hex characters and never the address
- [ ] after the scheduled run only the current window remains (`/__scheduled` under `wrangler dev --test-scheduled`, or the function called directly)
- [ ] `npm test` and `tsc` clean
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- Follows `takeAutofillUnit`, including `changes() = 1` on the second update.
- Seed the counters through `d1()` in `test/helpers.mjs`, as `test/autofill.test.mjs` does; test addresses come from 203.0.113.0/24.
