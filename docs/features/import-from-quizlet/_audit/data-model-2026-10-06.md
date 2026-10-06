# Audit — data-model, import-from-quizlet (2026-10-06)

**Migrations are staged — not yet in the live `vocab-photo-api/migrations/` tree; `implement` promotes them.**

| Staged file | Promote to |
|---|---|
| `docs/features/import-from-quizlet/migrations/01_add_set_sources.up.sql` | `vocab-photo-api/migrations/<next>_set_sources.sql` |
| `docs/features/import-from-quizlet/migrations/01_add_set_sources.down.sql` | `vocab-photo-api/migrations/down/<next>_set_sources.sql`, replacing `<next>` in its last statement |

**Promote-time hint:** the repo numbers D1 migrations sequentially with 4 digits (`0001_sessions.sql`, `0002_subtitle_imports.sql`), downs mirrored under `migrations/down/` so `wrangler d1 migrations apply` never runs them. Next ≈ `0003` — `implement` assigns the real number at promotion, since another feature may promote first. Apply with `npx wrangler d1 migrations apply DB --remote` before the Worker deploy (sad §7).

**Conventions:** followed `0001_sessions.sql` — snake_case, TEXT keys, composite PK, `CHECK` constraints including cross-column ones, cascade from `sessions`, text limits in code. **Deviation:** none. Table rebuild instead of `ALTER TABLE ADD COLUMN` was chosen by the owner to keep cross-column checks in the schema, as `0001` does.

**Breaking-change decomposition:** not needed — new columns only, with a default that keeps existing rows and older Workers and app builds valid.

**Self-check (4 mandatory):**
- Naming matches the repo: ✓ (`sources`, `kind`, `name`, `url`, `sources_arrived_idx`; file name `<next>_set_sources.sql`).
- Down reversibility: ✓ — the rebuild is reversed by a rebuild; the re-created index is re-created; set data is removed explicitly (rows unlinked first). Verified up → down → up in SQLite.
- FK indexes: ✓ — `sources.session_id` leads the PK and `sources_arrived_idx`.
- Convention adherence: ✓.

**Drift (domain layer vs schema):** none today — `StoredSource` in `src/session/types.ts` (`id, ord, mediaType, bytes, status, arrivedRev`) matches `0001`'s `sources`; Isar `SourcePhoto` matches its generated schema. After this feature, `StoredSource` must gain `kind, name, url` and `SessionSource` must gain `kind, name, url` (data-model.md) — tracked for `tasks`, not a drift.

**Isar (no SQL):** `SourcePhoto` → `SessionSource` with `@Name('SourcePhoto')`, new `@enumerated SourceKind kind` (photo first — stored as ordinal), `String? name`, `String? url`. Needs `dart run build_runner build --delete-conflicting-outputs` and a test that a pre-change session reads with `kind == photo`.

**TBD:** none.

Next stage: `/sdd:api import-from-quizlet`.
