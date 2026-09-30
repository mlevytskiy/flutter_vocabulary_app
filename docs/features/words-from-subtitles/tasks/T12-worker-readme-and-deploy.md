---
id: T12
title: "Document the subtitle route, its migration and the AI stub in the Worker README"
layer: "docs"
deps: ["T4"]
acs: ["AC-13", "AC-14"]
files_hint: ["vocab-photo-api/README.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T12 — Document the subtitle route, its migration and the AI stub in the Worker README

## Why

[sad §7](../sad.md) Deployment view; [ADR-0003](../adr/0003-count-subtitle-imports-per-address-and-per-day-in-d1.md).

## What

- Extend the existing route, migration and testing sections of `vocab-photo-api/README.md`; don't start a new document.

## Definition of Done

**Done when:** The README describes `POST /subtitles/words` (link to the contract), the allowance limits and where to change them, `wrangler d1 migrations apply DB --remote` before deploy, the new cleanup delete, `ANTHROPIC_API_URL` for tests, and the log line fields; the documented commands work on a clean checkout.

- [ ] follow the README from a clean clone: `npm test` passes and `migrations apply --local` applies 0002
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)
