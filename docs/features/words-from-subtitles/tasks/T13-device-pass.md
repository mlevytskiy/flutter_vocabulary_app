---
id: T13
title: "Run the device pass for the spec §6 targets on 5 films and every model"
layer: "tests"
deps: ["T11", "T12"]
acs: ["AC-02", "AC-06", "AC-12", "AC-17", "AC-19", "AC-21"]
files_hint: ["docs/features/words-from-subtitles/_audit/device-pass.md"]
owner: "Maksym"
estimate: "M"
status: "blocked"
---

# T13 — Run the device pass for the spec §6 targets on 5 films and every model

## Why

[spec §6](../spec.md) NFR table; [sad §10](../sad.md) QG-1 and QG-2; [sad §11](../sad.md) ranking drift risk.

## What

- A manual pass on the owner's phone against the deployed Worker, recorded in `_audit/device-pass.md`. Spread it over two UTC days, because 4 models × 5 films reaches the 20-a-day cap (sad §11).

## Definition of Done

**Done when:** `_audit/device-pass.md` records, for 5 test films, the time to the results dialog at maximum 20 on Sonnet 5 (p95 ≤ 30 s), the times at maximum 100 for each of the four models, 0 partial lists, word counts ≤ the maximum, the top 20 at maximum 20 against maximum 30 per model (AC-19 drift, sad §11), and subtitle words shown like typed words in the words table, History, the shared link and the file export.

- [ ] the table filled in, with each target marked met or missed
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- **Blocked (implement, 2026-10-01):** needs the owner's phone, the deployed Worker (D1 migration 0002 applied remotely) and real Anthropic spend. The results sheet is ready at `_audit/device-pass.md`.

- If the AC-19 top-20 drifts, record it and raise the sad §11 fallback (rank once and cut on the phone) with the owner rather than changing code here.
