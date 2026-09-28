---
id: T4
title: "Move session storage to D1, with a lazy import of pre-feature KV links"
layer: "infra"
deps: ["T2", "T3"]
acs: ["AC-26", "AC-27", "AC-32"]
files_hint: ["vocab-photo-api/src/session/store.ts", "vocab-photo-api/src/session/types.ts", "vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/src/env.ts", "vocab-photo-api/test/store.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T4 — Move session storage to D1, with a lazy import of pre-feature KV links

## Why

[ADR-0003](../../../features/good-looking-web/adr/0003-store-editable-sessions-and-autofill-counters-in-d1.md); [sad §5](../../../features/good-looking-web/sad.md) store.ts. Acceptance criteria: [AC-26](../../../features/good-looking-web/spec.md), [AC-27](../../../features/good-looking-web/spec.md), [AC-32](../../../features/good-looking-web/spec.md).

## What

`store.ts` becomes a D1 repository: create session (rows with server ids for rows the app didn't id), load a session with its live rows and photo slots, treat `expires_at < now` as gone. `POST /sessions` writes D1 only and keeps storing every translation and definition it receives (AC-27). `GET /s/:id` loads from D1; on a miss it tries `SESSIONS` KV once, imports the document into D1 with its original expiry, then serves it. Unknown and expired ids share one gone response (AC-32). Limits in `types.ts` unchanged.

## Definition of Done

- [x] node test: publish → page shows the rows from D1
- [x] node test: a document seeded into local KV opens once, is imported, and a second open reads D1 (AC-26 for old links)
- [x] node test: expired and unknown ids get byte-identical gone pages (AC-32)
- [x] `npm run typecheck` clean
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Shares `types.ts`/`store.ts`/`handlers.ts` with T5–T7 — same lane.
