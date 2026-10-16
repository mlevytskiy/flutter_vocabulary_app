---
id: T26
title: "Update architecture.md, CONTEXT.md, the superseded ADRs and the Worker README"
layer: "docs"
deps: ["T11", "T13", "T23"]
acs: []
files_hint: ["docs/architecture.md", "CONTEXT.md", "docs/features/edit-session-from-history/adr/", "docs/features/import-from-quizlet/", "vocab-photo-api/README.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T26 — Update architecture.md, CONTEXT.md, the superseded ADRs and the Worker README

## Why

[sad §11](../sad.md#11-risks-and-technical-debt) brownfield drift and the "new writer must use update" mitigation; [sad §12](../sad.md#12-glossary) terms not yet in CONTEXT.md.

## What

- Docs only.

## Definition of Done

**Done when:** `docs/architecture.md` states the put()/update() rule for writers and the new launch rule; CONTEXT.md has "filing" and "kept collection"; edit-session-from-history ADR-0002/ADR-0003 and the import-from-quizlet drop rule are marked superseded by ADR-0006/ADR-0007; the Worker README documents `title` and migration 0007.

- [ ] links resolve
- [ ] no code change

## Notes

—
