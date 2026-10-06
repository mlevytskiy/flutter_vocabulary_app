---
id: T1
title: "Promote the set-sources migration into the Worker"
layer: "migration"
deps: []
acs: ["AC-13", "AC-13b"]
files_hint: ["docs/features/import-from-quizlet/migrations/01_add_set_sources.up.sql", "docs/features/import-from-quizlet/migrations/01_add_set_sources.down.sql", "vocab-photo-api/migrations/", "vocab-photo-api/migrations/down/"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Promote the set-sources migration into the Worker

## Why

[data-model.md](../data-model.md) §Migrations, [ADR-0006](../adr/0006-publish-set-sources-in-the-sources-list-with-a-kind.md), [sad §7](../sad.md) release order.

## What

- Copy the staged up/down into `vocab-photo-api/migrations/<next>_set_sources.sql` and `migrations/down/<next>_set_sources.sql` (next is `0003` today; take the next free number at promotion).
- Replace `<next>` in the down file's `DELETE FROM d1_migrations` line and in both header comments.

## Definition of Done

**Done when:** The staged pair is promoted as `<next>_set_sources.sql` (+ `down/`, `<next>` replaced in its last statement), applies with `wrangler d1 migrations apply DB --local` on a database holding photo slots, reverts with the down file, re-applies, and `npm test` still passes.

- [ ] `wrangler d1 migrations apply DB --local` succeeds on a database that already has photo slots; they read back as `kind = 'photo'`
- [ ] the down file reverts it, and the up re-applies
- [ ] `npm test` and `npm run typecheck` pass

## Notes

- Rebuild migration (owner's choice at data-model): `PRAGMA defer_foreign_keys = true`, new table, copy, drop, rename, re-create `sources_arrived_idx`. Already checked in SQLite 3 at data-model.
- Remote apply happens in T16, before the Worker deploy.
