---
id: T20
title: "Update the repo docs this design outdates and run the release checks"
layer: "docs"
deps: ["T9", "T16", "T17", "T19"]
acs: ["AC-06", "AC-07", "AC-18"]
files_hint: ["CLAUDE.md", "docs/architecture.md", "vocab-photo-api/README.md", "docs/features/learn-part-step-1/CONTEXT.md", "docs/features/mnemonic-story/CONTEXT.md", "docs/roadmap.md"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T20 — Update the repo docs this design outdates and run the release checks

## Why

[sad §11](../sad.md) "Repo texts this design outdates" and the Security review row; [spec §6](../spec.md) measurements done at release.

## What

- CLAUDE.md rule 3 (the new visible parts) and rule 5 (`WordGroup`, `StoryRun`, `StoryStep`, `WordPair.rowId` approved). architecture.md §1/§3 (`core/story/`, new features, routes, stores). The README (deploy order from sad §7). learn-part-step-1 CONTEXT ("the learn page saves nothing" narrowed). The glossary terms "offered AI list" and "grouped-words key". Roadmap status.
- Release checks on the owner's phone: grouping ≤ 30 s for 60 words (5 runs), saved story ≤ 500 ms (5 runs), 4× zoom with no blur at 2×, ≤ 3 MB per run after 10 runs, and a live run against real providers on a staging deploy. Security review sign-off.

## Definition of Done

**Done when:** The listed docs describe the shipped design, and the release-check results (grouping time, saved-open time, zoom, storage, staging run, security sign-off) are recorded in this task file's Notes.

- [ ] CLAUDE.md, architecture.md and README updated
- [ ] release measurements recorded
- [ ] Security Lead sign-off recorded

## Notes

- The story run time (≤ 3 min median of the first 10 runs) and the ±25 % price check happen after release, on the story runs screen.
