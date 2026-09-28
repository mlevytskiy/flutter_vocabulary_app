---
id: T18
title: "Publish rows with photo links and upload declared photos in the background"
layer: "app"
deps: ["T5", "T17"]
acs: ["AC-24", "AC-25", "AC-27", "AC-28", "AC-37"]
files_hint: ["lib/core/services/session_publish_service.dart", "lib/core/services/photo_upload_service.dart", "lib/core/providers.dart", "test/session_publish_service_test.dart", "test/photo_upload_service_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T18 — Publish rows with photo links and upload declared photos in the background

## Why

[ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md), [ADR-0008](../../../features/good-looking-web/adr/0008-overwrite-the-same-link-when-a-session-is-republished.md), [sad §6 flow 2](../../../features/good-looking-web/sad.md). Acceptance criteria: [AC-24](../../../features/good-looking-web/spec.md), [AC-25](../../../features/good-looking-web/spec.md), [AC-27](../../../features/good-looking-web/spec.md), [AC-28](../../../features/good-looking-web/spec.md), [AC-37](../../../features/good-looking-web/spec.md).

## What

Publish sends every stored translation and definition whatever the mode (AC-27), `detail` as today, and — when photos are included — `sources` (photos with ≥1 linked row, first 10 by taken time; returns the names of any left out) and each row's `sourceId`; with photos off, neither field. Sends `publishedId` + `editToken` when the session has them; stores the returned id and token. `photo_upload_service` (keepAlive provider) uploads each declared photo to its id with retries and back-off, never blocking the caller. The app's session is never changed by page edits (AC-28).

## Definition of Done

- [x] MockClient test: payload with photos off has no `sources`/`sourceId` (AC-24)
- [x] MockClient test: 11 photos → 10 declared, one reported left out (spec OQ-3)
- [x] MockClient test: a mode-translation session with stored definitions sends them (AC-27)
- [x] Upload test: two failures then success → uploaded; publish returns before any upload completes (AC-37)
- [x] `flutter analyze` adds no issue
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Needs the T5 Worker deployed first (sad §7).

`SessionPublishService.publish` now takes `sources`, `publishedId` and `editToken`. Every
stored translation and every non-empty definition is sent, whatever the mode (AC-27);
`detail` is sent as before. With `sources` empty (photos off), neither `sources` nor any
`sourceId` is sent (AC-24). Otherwise, only photos with at least one non-blank linked row
are declared: the first 10 by `takenAt`, sent as `{id, order}` in pager order. A row
keeps its `sourceId` only if its photo was declared. `PublishedSession` now carries
`editToken`, `declaredSources` and `leftOutSources`, so T19 can name the photos left out
(spec OQ-3). The id and token go out only as a pair.

`PhotoUploadService` (`photoUploadServiceProvider`, keepAlive) has `enqueue(publishedId,
photos)`, which returns at once. Each photo runs its own loop to
`POST /sessions/<id>/sources/<sourceId>` (`image/jpeg`, `x-app-secret`, 60 s timeout). A
loop tries up to 5 times, pausing 2, 4, 8 and 16 s. A network error, a 5xx or a 429 is
retried. Any other 4xx is a refusal and is not. A photo whose kept file is gone is
skipped. Nothing is thrown or shown; failures only reach `debugPrint` (sad §8). The same
photo for the same link is not started twice while running. `idle` is for tests.

Words table: publish sends the session's `publishedId`/`editToken`. `markShared` now
stores the returned pair; it is not a content change, so no timestamps move. A History
row that is not the current session is written to the store in the background, so the
link dialog does not wait on it. Declared photos go to `enqueue`, which is not awaited.
Until T19 adds the "include photos" switch, the screen passes `sources: const []`, so no
photo reaches a page yet. No widget changed.

Tests: `session_publish_service_test.dart` covers photos off; two photos declared by
taken time with typed and blank rows; 11 photos giving 10 declared and one left out (its
row unlinked); AC-27 in translation mode; and republish (no token first, id + token
after, an old Worker's answer with no token). `photo_upload_service_test.dart` covers the
path, headers and bytes; two failures then success, with growing pauses; publish
returning and the dialog step running before a gated upload completes (AC-37); giving up
after 5; no retry on 404; a missing file; and a duplicate enqueue. The notifier test
covers storing the id and token. `flutter test` passes 132 tests. `flutter analyze` still
reports the 9 infos it had before, and `npm run typecheck` is clean. No Worker code
changed, so `npm test` was not run. The grep finds only `PhotoScaler.instance`.

Left: T19 wires the switch (passes `session.sources` when on) and the left-out notice.
`docs/architecture.md` does not list `photo_upload_service.dart` yet; T21 updates the
docs.
