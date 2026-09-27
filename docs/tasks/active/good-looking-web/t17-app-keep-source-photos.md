---
id: T17
title: "Keep each source photo in the app and link recognised rows to it"
layer: "domain"
deps: []
acs: ["AC-25", "AC-26"]
files_hint: ["lib/core/models/source_photo.dart", "lib/core/models/session.dart", "lib/core/models/session.g.dart", "lib/core/models/word_pair.dart", "lib/core/models/word_pair.g.dart", "lib/core/services/photo_scaler.dart", "lib/core/services/source_photo_store.dart", "lib/core/providers.dart", "lib/features/word_input/", "test/"]
owner: "Maksym"
estimate: "M"
status: "review"
---

# T17 — Keep each source photo in the app and link recognised rows to it

## Why

[sad §2 override 2, §5 kept photo copy](../../../features/good-looking-web/sad.md); [ADR-0006](../../../features/good-looking-web/adr/0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after.md). Acceptance criteria: [AC-25](../../../features/good-looking-web/spec.md), [AC-26](../../../features/good-looking-web/spec.md).

## What

New `@embedded SourcePhoto` (id UUID, file name, takenAt); `Session.sources`, `Session.publishedId`, `Session.editToken`; `WordPair.sourceId`. `PhotoScaler` also produces a 1600 px (shorter side, JPEG 80) copy; `source_photo_store` writes it to the app documents dir via `path_provider`. After `/analyze`, recognised rows get the photo's id; typed rows none. Regenerate `.g.dart`.

## Definition of Done

- [x] Unit test: a session saved before this change loads with no sources and null sourceIds (AC-26)
- [x] Unit test: JSON round trip keeps sources, sourceId, publishedId, editToken
- [x] `dart run build_runner build --delete-conflicting-outputs` clean; `flutter analyze` adds no issue; CLAUDE.md greps clean
- [ ] On device: photographing a page tags its rows; a typed row has no photo (AC-25) (manual, pending user check)
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Input screen stays pixel-identical (CLAUDE.md rule 3). Can start at once — parallel to the whole Worker lane.

New `@embedded SourcePhoto` (`id`, `fileName`, `takenAt`) in `core/models/source_photo.dart`.
`Session` gets `sources`, `publishedId` and `editToken`; `WordPair` gets `sourceId`. All of them
are in `fromJson`/`toJson`, `WordPair.copy()` and `SessionStore.put`. A missing JSON key reads as
empty/null. So does a missing Isar property: the generated reader falls back to `[]` for
`sources`, so old stored sessions load unchanged (AC-26). The notifier makes `sources` growable
on load and restore, as it does for `words`.

`PhotoScaler.keptCopy(path)` runs `resizeFileToMinSide(minSide: 1600, quality: 80)` on the same
isolate. The 640 px `/analyze` call is unchanged. `SourcePhotoStore` (`sourcePhotoStoreProvider`,
keepAlive) writes the copy to `<documents>/source_photos/<uuid>.jpg` under a `Random.secure` v4
UUID (no new package), and can read and delete it. Like `SessionStore`, it never throws: if a photo
cannot be kept, its words still arrive, just untagged.

On the input screen, the kept copy starts once the 640 px copy is done, so it runs while
`/analyze` is out. When the result dialog closes with words, `addSource(photo)` goes to the
notifier first. Then every row added from that photo, including a reused empty first row, is
built by `wordPairFromPhoto(w, sourceId:)`. Typed rows never get a `sourceId`. If the dialog is
cancelled, nothing is selected or the analysis fails, the kept file is deleted, so a photo with no
rows is never listed. `updateAt` keeps `sourceId` unless it is named. Clearing row 0 with ×
passes `clearSourceId: true`. Deleting a row leaves its photo in `sources`, because T18 declares
only photos with at least one linked row. No widget changed.

`test/source_photo_test.dart` (11 tests): a legacy JSON session; the JSON round trip; `copy()`;
`wordPairFromPhoto` tagging; an Isar round trip, with and without photos; `SourcePhotoStore`
keep/read/delete and the UUID format; and the notifier: two photos plus a typed row saved and
reloaded, an edit keeping the link, a clear dropping it, and a stored session with sources taking
another photo. `flutter test` passes 117 tests. `flutter analyze` still reports the 9 infos it had
before. `npm run typecheck` is clean; no Worker code changed, so `npm test` was not run. The grep
finds only `PhotoScaler.instance`.

Left: the on-device check (AC-25). `docs/architecture.md` does not list the new files yet; T21
updates the docs.
