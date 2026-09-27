---
id: T10
title: "Build the AnkiDroid file from D1 and clean up expired sessions daily"
layer: "infra"
deps: ["T4"]
acs: ["AC-30", "AC-31", "AC-32"]
files_hint: ["vocab-photo-api/src/session/anki.ts", "vocab-photo-api/src/session/cleanup.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/wrangler.jsonc", "vocab-photo-api/test/download.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T10 — Build the AnkiDroid file from D1 and clean up expired sessions daily

## Why

[sad §4 columns + §7 cron](../../../features/good-looking-web/sad.md); definition-mode ADR-0005 fixed columns. Acceptance criteria: [AC-30](../../../features/good-looking-web/spec.md), [AC-31](../../../features/good-looking-web/spec.md), [AC-32](../../../features/good-looking-web/spec.md).

## What

`words.txt` reads live rows from D1: fixed places word/translation/definition/tags; a column with no text anywhere is written empty; rows with an empty word are left out. Add `scheduled()` + `triggers.crons: ["0 3 * * *"]`: deletes sessions past `expires_at` with their rows, slots and counter rows, and logs counts.

## Definition of Done

- [ ] node test: file contains edited values; empty-word and all-cleared rows absent (AC-30, AC-31)
- [ ] node test: invoking the scheduled handler removes an expired session; its page stays gone
- [ ] `npm run typecheck` clean
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

`anki.ts` sanitising unchanged (AC-33 in the file).
