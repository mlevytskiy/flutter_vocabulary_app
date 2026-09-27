---
id: T10
title: "Build the AnkiDroid file from D1 and clean up expired sessions daily"
layer: "infra"
deps: ["T4"]
acs: ["AC-30", "AC-31", "AC-32"]
files_hint: ["vocab-photo-api/src/session/anki.ts", "vocab-photo-api/src/session/cleanup.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/wrangler.jsonc", "vocab-photo-api/test/download.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T10 — Build the AnkiDroid file from D1 and clean up expired sessions daily

## Why

[sad §4 columns + §7 cron](../../../features/good-looking-web/sad.md); definition-mode ADR-0005 fixed columns. Acceptance criteria: [AC-30](../../../features/good-looking-web/spec.md), [AC-31](../../../features/good-looking-web/spec.md), [AC-32](../../../features/good-looking-web/spec.md).

## What

`words.txt` reads live rows from D1: fixed places word/translation/definition/tags; a column with no text anywhere is written empty; rows with an empty word are left out. Add `scheduled()` + `triggers.crons: ["0 3 * * *"]`: deletes sessions past `expires_at` with their rows, slots and counter rows, and logs counts.

## Definition of Done

- [x] node test: file contains edited values; empty-word and all-cleared rows absent (AC-30, AC-31)
- [x] node test: invoking the scheduled handler removes an expired session; its page stays gone
- [x] `npm run typecheck` clean
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

`anki.ts` sanitising unchanged (AC-33 in the file).

The page's file no longer follows the session's `detail`: it writes every stored translation and
definition (AC-27, AC-30), so an all-empty column comes out empty by itself. The row filter is
now "word is blank after sanitising" (AC-31) instead of "all three blank". The app's
`anki_export.dart` is unchanged (it still follows the current mode); README § "AnkiDroid file
format" describes both writers.

Clean-up (`src/session/cleanup.ts`): one D1 batch deletes `rows`, `sources` and `page_autofill`
of the sessions with `expires_at < now`, then the sessions, and logs `expired sessions deleted`
with the four counts. Deleted by name, not through `ON DELETE CASCADE`, so the counts are real
and nothing depends on D1's foreign-key setting. `all_pages_autofill` stays (not a session's).
R2 bytes are left to the bucket's lifecycle rule (sad §11). The `scheduled()` handler awaits the
clean-up rather than `waitUntil`, so `GET /__scheduled` (`wrangler dev --test-scheduled`, now
passed by `scripts/test.mjs`) returns after it finished. Tests in `test/download.test.mjs`.
