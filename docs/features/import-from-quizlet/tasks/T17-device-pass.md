---
id: T17
title: "Run the device pass for the spec §6 targets on real Quizlet sets"
layer: "tests"
deps: ["T16", "T18", "T19"]
acs: ["AC-02", "AC-05", "AC-07", "AC-11", "AC-13", "AC-14"]
files_hint: ["docs/features/import-from-quizlet/_audit/device-pass.md"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T17 — Run the device pass for the spec §6 targets on real Quizlet sets

## Why

spec §6 NFR table; [sad §10](../sad.md) QG-1, QG-2, QG-3; [sad §11](../sad.md) parser and robot-check risks.

## What

- A manual pass on the owner's phones against the deployed Worker; the results sheet in `_audit/device-pass.md`.

## Definition of Done

**Done when:** `_audit/device-pass.md` records, on iPhone and Android: p95 time to the results dialog for 3 public 100-card sets (5 runs each, ≤ 10 s), sets of 10/50/200/500 cards read whole with no "Read X of Y" line, the 30 ± 2 s AC-07 end on a page with no cards, a robot check passed on the page shown full size in place of the cards, the skeleton → cards → scroll sequence and the + menu, link dialog and photo source dialog looks, a tapped advert or outside link opening nothing, no new permission prompt on a fresh install, and the set page on the shared page wide and on a phone.

- [ ] the table filled in, each target marked met or missed
- [ ] any parser miss turned into a new fixture for T7's tests

## Notes

- Needs the owner's phones and real sets of 200 and 500 cards (find or create them beforehand).
