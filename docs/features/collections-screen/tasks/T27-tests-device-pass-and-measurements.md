---
id: T27
title: "Run the device pass: the update over a copy of the owner's data, open time, force-close durability, and deploy the Worker"
layer: "tests"
deps: ["T6", "T10", "T18", "T19", "T24", "T25", "T26"]
acs: ["AC-04", "AC-05", "AC-14", "AC-26", "AC-27"]
files_hint: ["docs/features/collections-screen/device-pass.md"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T27 — Run the device pass: the update over a copy of the owner's data, open time, force-close durability, and deploy the Worker

## Why

QG-2, QG-3, QG-4 and the device checks named in [sad §10](../sad.md#10-quality-requirements) and [sad §11](../sad.md#11-risks-and-technical-debt); [sad §7](../sad.md#7-deployment-view) deploy order.

## What

- Owner-run on the phone; record numbers and any finding in `device-pass.md`.
- If QG-3 misses 500 ms, stop and ask the owner about a stored word count (new data, rule 5) — do not add it.

## Definition of Done

**Done when:** A written device-pass record shows: QG-2 counts before = after on a copy of the owner's real data (words, sources, dialogues, groups, results, tags, story runs, photo files) with every collection at the top level named from its creation moment; QG-3 Collections ready ≤ 500 ms with 300 collections and 50 folders in a release profile run; QG-4 a drop, rename, delete and restore each survive a force-close 1 s later; long names and drags checked by hand; migration 0007 applied remotely and the Worker deployed.

- [ ] every QG row has a measured number
- [ ] Worker deployed after `wrangler d1 migrations apply DB --remote`

## Notes

Full regression (`tool/test.sh full`) only if the owner asks (CLAUDE.md rule 7).
