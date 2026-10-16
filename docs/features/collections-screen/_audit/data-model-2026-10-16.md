# Audit — data-model, collections-screen (2026-10-16)

**Migrations are staged — not yet in the live `vocab-photo-api/migrations/` tree; `implement` promotes them.**

| Staged file | Promote to |
|---|---|
| `docs/features/collections-screen/migrations/01_add_session_title.up.sql` | `vocab-photo-api/migrations/<next>_session_title.sql` |
| `docs/features/collections-screen/migrations/01_add_session_title.down.sql` | `vocab-photo-api/migrations/down/<next>_session_title.sql`, replacing `<next>` in its comments and last statement |

**Promote-time hint:** the repo numbers D1 migrations sequentially with 4 digits (`0001_sessions.sql` … `0006_learn_allowance.sql`). Downs are mirrored under `migrations/down/` so `wrangler d1 migrations apply` never runs them. Next is about `0007`; `implement` assigns the real number at promotion, since another feature may promote first. Apply with `npx wrangler d1 migrations apply DB --remote` before the Worker deploy (sad §7). An older app and an older Worker both stay compatible: the column is nullable, and an old Worker ignores `title`.

**Isar (no SQL, the phone):**
- `Session` → `WordCollection` with `@Name('Session')`, and `sessionId` → `collectionId` with `@Name('sessionId')`.
- New properties: `String? name`, `String? folderId` (`@Index()`), `int order`, `DateTime? binnedAt` (`@Index()`), `String? binnedFromFolderId`, `bool keep`.
- New collection `CollectionFolder`, added to `Isar.open([...])`.
- `StoryRun.sessionId` → `collectionId` with `@Name('sessionId')`.
- Needs `dart run build_runner build --delete-conflicting-outputs`. The generated schema must keep collection name `Session` and property name `sessionId`. The check: diff `word_collection.g.dart`'s schema `name:` and index names against today's `session.g.dart`.
- The one-time backfill and the removal of the retired `shared_preferences` keys run in code when the store opens (data-model.md). They are not migration files.

**Conventions:**
- D1 follows `0001_sessions.sql` and `0005_film_dialogues.sql`: snake_case, `ALTER TABLE … ADD COLUMN` for an added column, text limits checked in code, and the down's last statement deletes the `d1_migrations` row.
- Isar follows `session.dart` / `story_run.dart`: `Id id = Isar.autoIncrement` plus a unique hash-indexed string id, nullable fields for "not set", stored names pinned with `@Name` (precedent `SessionSource` → `SourcePhoto`).
- **Deviation:** none.

**Breaking-change decomposition:** not needed.
- D1: one nullable column. Rows, routes and older clients are unaffected.
- Isar: new properties only. Old records read them as null/0/false and are backfilled once. The rename changes Dart names only (pinned by `@Name`), so the stored schema does not change.

**Self-check (4 mandatory):**
- **Naming matches the repo:** ✓ — `title`, `<next>_session_title.sql`; Isar camelCase properties as in `session.dart`.
- **Down reversibility:** ✓ — `ADD COLUMN title` is reversed by `DROP COLUMN title`, and the migration is forgotten. Verified up → down → up with sqlite3 over `0001_sessions.sql` and a stub `d1_migrations` table, with an existing row reading `title IS NULL`. Isar: dropping the new properties in a rollback build is harmless (Isar ignores unknown stored properties). Dart names can be renamed back freely because the stored names never changed.
- **FK indexes:** ✓ — no new D1 foreign key. On Isar the logical references are `folderId` (indexed) and `parentId` (deliberately not indexed: ≤ 50 folders are read whole, data-model.md § Indexes). `binnedFromFolderId` is only read for one item at restore time.
- **Convention adherence:** ✓.

**Drift (domain layer vs schema):**
- None today. `Session` and `StoryRun` match their generated Isar schemas (generated from them). `StoredSession` in `src/session/types.ts` matches the columns `store.ts` reads from `sessions`.
- After this feature, `StoredSession` gains `title: string | null` and the publish body type gains an optional `title`. That's tracked for `tasks`, not drift.

**TBD:**
- None in the schema.
- The restore position (spec §8, sad §11, due before `sdd:screens`) needs no schema choice: a binned item keeps its `order`, so either answer works on this model.

Next stage: `/sdd:api collections-screen`.
