---
id: T18
title: "Publish rows with photo links and upload declared photos in the background"
layer: "app"
deps: ["T5", "T17"]
acs: ["AC-24", "AC-25", "AC-27", "AC-28", "AC-37"]
files_hint: ["lib/core/services/session_publish_service.dart", "lib/core/services/photo_upload_service.dart", "lib/core/providers.dart", "test/session_publish_service_test.dart", "test/photo_upload_service_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T18 — Publish rows with photo links and upload declared photos in the background

## Why

[ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md), [ADR-0008](../../../features/good-looking-web/adr/0008-overwrite-the-same-link-when-a-session-is-republished.md), [sad §6 flow 2](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-24](../../../features/good-looking-web/spec.md), [AC-25](../../../features/good-looking-web/spec.md), [AC-27](../../../features/good-looking-web/spec.md), [AC-28](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Publish sends every stored translation and definition whatever the mode (AC-27), `detail` as today, and — when photos are included — `sources` (photos with ≥1 linked row, first 10 by taken time; returns the names of any left out) and each row's `sourceId`; with photos off, neither field. Sends `publishedId` + `editToken` when the session has them; stores the returned id and token. `photo_upload_service` (keepAlive provider) uploads each declared photo to its id with retries and back-off, never blocking the caller. The app's session is never changed by page edits (AC-28).

## Definition of Done

- [ ] MockClient test: payload with photos off has no `sources`/`sourceId` (AC-24)
- [ ] MockClient test: 11 photos → 10 declared, one reported left out (spec OQ-3)
- [ ] MockClient test: a mode-translation session with stored definitions sends them (AC-27)
- [ ] Upload test: two failures then success → uploaded; publish returns before any upload completes (AC-37)
- [ ] `flutter analyze` adds no issue
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Needs the T5 Worker deployed first (sad §7).
