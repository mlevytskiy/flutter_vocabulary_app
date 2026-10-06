---
id: T16
title: "Update the architecture docs and deploy the Worker with the migration"
layer: "docs"
deps: ["T3", "T14", "T15"]
acs: ["AC-13", "AC-14", "AC-15"]
files_hint: ["docs/architecture.md", "vocab-photo-api/README.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T16 — Update the architecture docs and deploy the Worker with the migration

## Why

[sad §7](../sad.md) release order; [sad §11](../sad.md) repo-text row.

## What

- Text updates; `wrangler d1 migrations apply DB --remote`; `wrangler deploy`; a publish from the current store build as the check.

## Definition of Done

**Done when:** `docs/architecture.md` describes `session_source.dart`, the source cap removal, "Include sources", the `quizlet_*` files and the flow; the Worker README notes set sources; the migration is applied with `--remote`, then the Worker deployed, in the sad §7 order, and an older app build still publishes photos.

- [ ] docs updated
- [ ] remote migration applied and Worker deployed
- [ ] a publish from an older app build still works

## Notes

- Deploy needs the owner's Cloudflare credentials — run by the owner.
