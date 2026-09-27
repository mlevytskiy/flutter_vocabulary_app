---
id: T3
title: "Create the D1 schema for sessions, rows, cell revisions, photo slots and counters"
layer: "migration"
deps: []
acs: ["AC-11", "AC-12", "AC-15b", "AC-18", "AC-18b"]
files_hint: ["docs/features/good-looking-web/migrations/0001_sessions.up.sql", "docs/features/good-looking-web/migrations/0001_sessions.down.sql", "vocab-photo-api/wrangler.jsonc"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T3 — Create the D1 schema for sessions, rows, cell revisions, photo slots and counters

## Why

[ADR-0003](../../../features/good-looking-web/adr/0003-store-editable-sessions-and-autofill-counters-in-d1.md), [ADR-0004](../../../features/good-looking-web/adr/0004-detect-edit-conflicts-with-a-revision-per-cell.md), [ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md), [ADR-0008](../../../features/good-looking-web/adr/0008-overwrite-the-same-link-when-a-session-is-republished.md). `data-model` was skipped, so the schema is fixed here. Acceptance criteria: [AC-11](../../../features/good-looking-web/spec.md), [AC-12](../../../features/good-looking-web/spec.md), [AC-15b](../../../features/good-looking-web/spec.md), [AC-18](../../../features/good-looking-web/spec.md), [AC-18b](../../../features/good-looking-web/spec.md).

## What

Tables: `sessions` (id, created_at, expires_at, rev, detail, edit_token_hash); `rows` (id, session_id, position, source_id NULL, word/translation/definition + one `*_rev` each, `deleted_at_rev` NULL for the tombstone); `sources` (id, session_id, ord, media_type, bytes, status pending|arrived, arrived_rev); `page_autofill` (session_id, utc_day, used); `all_pages_autofill` (utc_day, used). Indexes for "rows of a session changed after rev N" and "sessions past expires_at". `wrangler.jsonc` gains the `DB` D1 binding and `migrations_dir`.

## Definition of Done

- [x] Staged migration is promoted to `vocab-photo-api/migrations/`, then `wrangler d1 migrations apply --local` applies it and the down file reverts it cleanly
- [x] `npm run typecheck` clean with the new `DB` binding in `env.ts`
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Migration lane — serialized. Location hint for the remote database: near the owner (sad §11).
