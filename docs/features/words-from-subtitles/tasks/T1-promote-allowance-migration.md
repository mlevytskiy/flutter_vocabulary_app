---
id: T1
title: "Promote the subtitle allowance migration into the Worker"
layer: "migration"
deps: []
acs: ["AC-14"]
files_hint: ["docs/features/words-from-subtitles/migrations/01_create_subtitle_imports.up.sql", "docs/features/words-from-subtitles/migrations/01_create_subtitle_imports.down.sql", "vocab-photo-api/migrations/", "vocab-photo-api/migrations/down/"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T1 — Promote the subtitle allowance migration into the Worker

## Why

[data-model.md](../data-model.md) and [ADR-0003](../adr/0003-count-subtitle-imports-per-address-and-per-day-in-d1.md): the allowance counters need their two tables before any Worker code can take a unit.

## What

- Move the staged pair into the live tree at the next number (today `0002`): `migrations/0002_subtitle_imports.sql` and `migrations/down/0002_subtitle_imports.sql`.
- Replace `<next>` in both files (header comments and the `DELETE FROM d1_migrations` line) and drop the STAGED wording from the header.
- Delete the staged copies from `docs/features/words-from-subtitles/migrations/` once promoted, or leave a one-line pointer, whichever the good-looking-web promotion did.

## Definition of Done

**Done when:** The staged pair is promoted as 0002_subtitle_imports.sql (+ down/), applies with `wrangler d1 migrations apply DB --local`, reverts with the down file, re-applies, and `npm test` still passes on the fresh database.

- [ ] `npx wrangler d1 migrations apply DB --local` applies `0002_subtitle_imports.sql`
- [ ] the down file reverts it and `migrations apply` re-applies it
- [ ] `npm test` passes (the harness starts from a fresh database with every migration applied)
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- `layer: migration`, so `implement` serializes it. Use the number that is actually next at promotion time; another feature may have taken 0002.
