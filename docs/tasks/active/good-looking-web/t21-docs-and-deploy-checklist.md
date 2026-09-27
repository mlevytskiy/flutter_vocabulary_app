---
id: T21
title: "Update the docs and run the deploy checklist"
layer: "docs"
deps: ["T10", "T19", "T20"]
acs: ["AC-24", "AC-32"]
files_hint: ["vocab-photo-api/README.md", "docs/architecture.md", "docs/tasks/README.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T21 — Update the docs and run the deploy checklist

## Why

[sad §7](../../../features/good-looking-web/sad.md) release order and monitoring; [sad §11](../../../features/good-looking-web/sad.md) R2 lifecycle risk. Acceptance criteria: [AC-24](../../../features/good-looking-web/spec.md), [AC-32](../../../features/good-looking-web/spec.md).

## What

README: create the D1 database (location hint), apply migrations, the cron trigger, `PAGE_WRITE_LIMITER`, confirm the R2 30-day lifecycle rule, the KV-removal reminder 30 days after release, and the KPI SQL queries. `docs/architecture.md`: the new models, services and providers. Execute the release order: D1 → Worker deploy → app build.

## Definition of Done

- [ ] README steps followed on the real account; R2 lifecycle rule confirmed (screenshot or dashboard note)
- [ ] A published link from the new app shows photos on the deployed page
- [ ] docs/tasks/README.md row updated with status and commits
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

The dictionary licence question (sad §11) stays with the owner.
