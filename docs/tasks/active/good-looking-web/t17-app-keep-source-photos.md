---
id: T17
title: "Keep each source photo in the app and link recognised rows to it"
layer: "domain"
deps: []
acs: ["AC-25", "AC-26"]
files_hint: ["lib/core/models/source_photo.dart", "lib/core/models/session.dart", "lib/core/models/session.g.dart", "lib/core/models/word_pair.dart", "lib/core/models/word_pair.g.dart", "lib/core/services/photo_scaler.dart", "lib/core/services/source_photo_store.dart", "lib/core/providers.dart", "lib/features/word_input/", "test/"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T17 — Keep each source photo in the app and link recognised rows to it

## Why

[sad §2 override 2, §5 kept photo copy](../../../features/good-looking-web/sad.md); [ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md). Acceptance criteria: [AC-25](../../../features/good-looking-web/spec.md), [AC-26](../../../features/good-looking-web/spec.md).

## What

New `@embedded SourcePhoto` (id UUID, file name, takenAt); `Session.sources`, `Session.publishedId`, `Session.editToken`; `WordPair.sourceId`. `PhotoScaler` also produces a 1600 px (shorter side, JPEG 80) copy; `source_photo_store` writes it to the app documents dir via `path_provider`. After `/analyze`, recognised rows get the photo's id; typed rows none. Regenerate `.g.dart`.

## Definition of Done

- [ ] Unit test: a session saved before this change loads with no sources and null sourceIds (AC-26)
- [ ] Unit test: JSON round trip keeps sources, sourceId, publishedId, editToken
- [ ] `dart run build_runner build --delete-conflicting-outputs` clean; `flutter analyze` adds no issue; CLAUDE.md greps clean
- [ ] On device: photographing a page tags its rows; a typed row has no photo (AC-25)
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Input screen stays pixel-identical (CLAUDE.md rule 3). Can start at once — parallel to the whole Worker lane.
