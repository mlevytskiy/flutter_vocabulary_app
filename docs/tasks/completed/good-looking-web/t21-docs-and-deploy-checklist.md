---
id: T21
title: "Update the docs and run the deploy checklist"
layer: "docs"
deps: ["T10", "T19", "T20"]
acs: ["AC-24", "AC-32"]
files_hint: ["vocab-photo-api/README.md", "docs/architecture.md", "docs/tasks/README.md"]
owner: "Maksym"
estimate: "S"
status: "in_progress"
---

# T21 — Update the docs and run the deploy checklist

## Why

[sad §7](../../../features/good-looking-web/sad.md) release order and monitoring; [sad §11](../../../features/good-looking-web/sad.md) R2 lifecycle risk. Acceptance criteria: [AC-24](../../../features/good-looking-web/spec.md), [AC-32](../../../features/good-looking-web/spec.md).

## What

README: create the D1 database (location hint), apply migrations, the cron trigger, `PAGE_WRITE_LIMITER`, confirm the R2 30-day lifecycle rule, the KV-removal reminder 30 days after release, and the KPI SQL queries. `docs/architecture.md`: the new models, services and providers. Execute the release order: D1 → Worker deploy → app build.

## Definition of Done

- [ ] README steps followed on the real account (D1, R2 and Worker deploy done 2026-09-28; app build pending); R2 lifecycle rule confirmed ✔ (`wrangler r2 bucket lifecycle list`, 2026-09-28)
- [ ] A published link from the new app shows photos on the deployed page
- [ ] docs/tasks/README.md row updated with status and commits
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

The dictionary licence question (sad §11) stays with the owner.

2026-09-28: README "Deploying good-looking-web (checklist)" and "KPIs" written; architecture.md
has `SourcePhoto`, `SourcePhotoStore`, `PhotoUploadService`, their providers and the Session /
WordPair fields. Checked on the real account: D1 `vocab-sessions` exists, `migrations list
--remote` → nothing to apply; R2 `vocab-photo-sources` has `expire-sources` (enabled, all
prefixes, expire after 30 days). The deployed Worker version is from 2026-09-27 20:37 UTC,
before T14–T16 changed `src/` — the Worker deploy, the app build and the photo check on the
deployed page were still to do.

2026-09-28 05:40 UTC: Worker deployed, version `b4149c70-5bc8-4bda-9154-ce864e45a638` (cron
`0 3 * * *` and `PAGE_WRITE_LIMITER` bound). Smoke test on the live Worker, scripted with the
app's secret: publish with one declared photo → 200 with an edit token; page renders rows, the
photo slot and the versioned script; photo upload 200 and `GET` 200 `image/png`; cell save 200,
a stale save 409 `conflict`; `/changes?since=0` returns the cell and the arrived photo;
`/words.txt` holds the edit; unknown id 404. Two pre-release KV links open with their rows.
Left: release the app build and check a publish from it shows photos on the deployed page. KPI 2 as narrowed in sad §7 ("among publishes with ≥1 declared
photo") is 100% by construction; the README query uses every publish as the denominator.
