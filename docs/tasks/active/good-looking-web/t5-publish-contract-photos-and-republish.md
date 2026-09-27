---
id: T5
title: "Accept declared photos, row photo ids and republish tokens in the publish contract"
layer: "ports"
deps: ["T4"]
acs: ["AC-24", "AC-25", "AC-34", "AC-37"]
files_hint: ["vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/src/session/types.ts", "vocab-photo-api/src/session/store.ts", "vocab-photo-api/test/publish.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T5 — Accept declared photos, row photo ids and republish tokens in the publish contract

## Why

[ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md), [ADR-0008](../../../features/good-looking-web/adr/0008-overwrite-the-same-link-when-a-session-is-republished.md), [sad §6 flow 2](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-24](../../../features/good-looking-web/spec.md), [AC-25](../../../features/good-looking-web/spec.md), [AC-34](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Publish accepts optional `sources: [{id, order}]` (≤ 10) and `sourceId` per entry (must name a declared source); stores pending photo slots. Returns `{id, url, expiresAt, editToken}`; stores only the SHA-256 of the token. A request with `publishedId` + a matching token replaces rows and slots, keeps `expires_at`, raises the revision and records "replaced at revision R" (never resets it); an expired id or wrong token creates a new link. The photo upload route stores bytes only for a declared, pending id of that session (repeat = no-op) and marks the slot arrived. `GET /s/:id/sources/:sourceId` serves only arrived slots of that session; anything else is gone (AC-24).

## Definition of Done

- [ ] node test: publish with 2 declared photos and linked rows → page data links rows to slots; typed rows have none (AC-25)
- [ ] node test: upload to an undeclared id is refused; a repeated upload is a no-op
- [ ] node test: a session published without `sources` answers gone for any guessed photo path (AC-24)
- [ ] node test: republish with the token keeps the link and expiry and replaces rows; a wrong token yields a new link
- [ ] node test: an old-shape publish (no sources, no token) still succeeds
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Deploy before the app build from T18 (sad §7 release order).
