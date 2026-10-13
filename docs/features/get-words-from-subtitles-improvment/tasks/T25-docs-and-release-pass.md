---
id: T25
title: "Update the repo docs this design outdates and run the release checks"
layer: "docs"
deps: ["T10", "T19", "T22", "T24"]
acs: []
files_hint: ["docs/architecture.md", "vocab-photo-api/README.md", "docs/features/get-words-from-subtitles-improvment/spec.md", "docs/features/get-words-from-subtitles-improvment/CONTEXT.md", "docs/features/get-words-from-subtitles-improvment/tasks/tracker.md"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T25 — Update the repo docs this design outdates and run the release checks

## Why

[sad §7](../sad.md), [sad §11](../sad.md), [sad §1](../sad.md) Decision overrides.

## What

- `docs/architecture.md`: folder layout and "How the pieces talk" gain dialogues, the push outbox, the dialogue screen and scene runs. The Worker README gains the new routes and migration 0005.
- Align spec §1, AC-20 and CONTEXT.md "dialogue page" with ADR-0005 (the §1 Decision override); add the three new terms (scene run, import id, pending delivery).
- Release checks with the owner: `wrangler d1 migrations apply`, then `wrangler deploy`, then the app build. Then the spec §6 device pass: 5 films × 2 at maximum 20 and 100, switch on and off, per model, plus a scene picture per picture maker.

## Definition of Done

**Done when:** The docs describe what shipped, and the device pass results are recorded against every spec §6 row.

- [ ] docs updated and reviewed
- [ ] device pass results noted in the tracker
- [ ] migration and deploy done by the owner, never by an agent

## Notes

- Deploy and secrets wait for the owner, as in mnemonic-story.
- Implement, 2026-10-13: docs done (`docs/architecture.md`, `vocab-photo-api/README.md` routes, scene runs, change feed, migration 0005 and a deploy checklist; spec §1 and AC-20 and CONTEXT.md aligned with ADR-0005; scene run, import id and pending delivery added to CONTEXT.md). Blocked on the owner: `wrangler d1 migrations apply`, `wrangler deploy`, the app build, and the spec §6 device pass, whose results go in the tracker.
