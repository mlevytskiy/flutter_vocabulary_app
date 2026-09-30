# Audit — data-model — words-from-subtitles — 2026-09-30

**Size / route:** S / quick (from `.size` / `.route`). **Mode:** brownfield delta (new tables only).

> **Migrations are staged, not yet in the live `migrations/` tree; `implement` promotes them.**

## Staged migrations

| Staged file | Promote to |
|---|---|
| `docs/features/words-from-subtitles/migrations/01_create_subtitle_imports.up.sql` | `vocab-photo-api/migrations/<next>_subtitle_imports.sql` |
| `docs/features/words-from-subtitles/migrations/01_create_subtitle_imports.down.sql` | `vocab-photo-api/migrations/down/<next>_subtitle_imports.sql` |

**Promote-time hint:** wrangler D1 migrations (`migrations_dir: "migrations"` in `wrangler.jsonc`). The naming is sequential 4-digit `NNNN_<name>.sql`; down files sit in `migrations/down/` under the same name, where `migrations apply` never picks them up. The next number is about `0002`; `implement` assigns the real one when it promotes and replaces `<next>` in both files, including the `DELETE FROM d1_migrations` line of the down file. The sad (§5, §7) already names it `0002_subtitle_imports`.

## Convention source

- No `docs/architecture-map.md` (survey was not run). The conventions come from the sad (§5, §7, §8) and ADR-0003, and they match the live `vocab-photo-api/migrations/0001_sessions.sql` and `src/autofill/meter.ts`.
- They were followed as found: `snake_case` names, `TEXT` ISO-8601 UTC times, `CHECK` constraints, composite natural primary keys, no audit columns on counters, hard delete by the daily cron, and the two-table counter pair with one atomic batch.

## Deviations and decisions

| Item | Note |
|---|---|
| Two tables, not one `subtitle_imports` | ADR-0003 says "`subtitle_imports` rows keyed by (hash, window start) and a per-UTC-day total row". The address windows keep the name `subtitle_imports`. The day total gets its own table `all_subtitle_imports`, following the `page_autofill` / `all_pages_autofill` precedent. This is not a change to the decision. |
| `IF NOT EXISTS` | `0001_sessions.sql` does not use it. Here it is added so a partly applied migration can be re-run (a data-model safety rule). It has no effect on a clean apply. |
| Cleanup cutoff | The cleanup deletes windows that start before the *current* window, not "older than 24 h". A 24 h cutoff with a once-a-day cron would keep rows for up to about 48 h, which breaks spec §6.1 "deletes it within a day". `implement` should write `session/cleanup.ts` this way. |
| `all_subtitle_imports` not cleaned | It holds no address data, so it is kept, like `all_pages_autofill` (one row a day). |
| `ip_hash` length CHECK | `length = 64` rejects writing a raw address by mistake. |

## Breaking changes

None. Both tables are new, so no expand, backfill or contract steps are needed.

## Drift

- No existing table or domain type is touched. The Worker has no code for these tables yet, and the Isar word row and the D1 `sessions` / `rows` / `sources` tables do not change (AC-17, spec §3). No `_drift/` files.

## Self-check

| Check | Result |
|---|---|
| Naming follows the repo | ✅ |
| Down reverses up | ✅ 2 × CREATE TABLE → DROP TABLE, 1 × CREATE INDEX → DROP INDEX, then the `d1_migrations` row is removed |
| FK indexes | ✅ n/a (no FKs) |
| Convention adherence | ✅ with the deviations above |
| Dry run | ✅ `sqlite3 :memory:`: up applied twice, then down; 12 simulated takes → window 10 / day 10; the cleanup `DELETE` uses `subtitle_imports_window_start_idx` |
| Mermaid `erDiagram` | ✅ structural lint only (no `mmdc` installed) |
| PII | ✅ only hashes are stored; fixtures use 203.0.113.0/24 |

## TBD

None. The default-level TBD was resolved during the `api` stage (2026-09-30): the preferences table now follows the owner's decision recorded in the sad §6 sequences notes (one set of values, an "Update with each import" switch, first launch B2). The spec amendment for it is still pending `/sdd:clarify`.
