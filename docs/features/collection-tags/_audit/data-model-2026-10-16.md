# Data-model audit — collection-tags — 2026-10-16

- **Staged migrations:** none. The phone uses Isar, and schema changes come from adding properties plus a Dart backfill (`_backfillTypedTags`, see data-model.md). Nothing was written to any live migrations tree, and the Worker's D1 is untouched.
- **Promote-time hint:** N/A. No SQL. `implement` regenerates the Isar schema with `dart run build_runner build --delete-conflicting-outputs`.
- **Convention deviations:** none. New properties have defaults, stored names stay pinned, and the backfill follows `_backfillFiling`.
- **Self-check:**
  - naming matches the repo: ok
  - reversibility: a forward-only app store, accepted and documented
  - FK indexes: N/A, since Isar has no FKs and links are by id
  - convention adherence: ok
- **Drift findings:** none (models are the schema source).
- **Breaking-change decomposition:** the legacy `tags` stays in the schema (expand). The migration fills the typed lists and empties `tags` (backfill). The property is not removed (no contract step, accepted debt in sad §11).
- **TBD:** none.
- **Next stage:** `api` is N/A (no Worker or contract change), so screens comes next.
