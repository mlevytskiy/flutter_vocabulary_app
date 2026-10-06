---
id: T4
title: "Generalise SourcePhoto into SessionSource with a kind, name and link"
layer: "domain"
deps: []
acs: ["AC-13b", "AC-15"]
files_hint: ["lib/core/models/source_photo.dart", "lib/core/models/session_source.dart", "lib/core/models/session.dart", "lib/core/models/word_pair.dart", "lib/core/providers.dart", "lib/core/services/source_photo_store.dart", "lib/core/services/photo_upload_service.dart", "lib/core/services/session_publish_service.dart", "lib/features/word_input/word_input_notifier.dart", "lib/features/word_input/word_input_screen.dart", "lib/features/words_table/photo_viewer.dart", "lib/features/words_table/words_table_screen.dart", "test/source_photo_test.dart", "test/words_table_test.dart", "test/photo_upload_service_test.dart", "test/session_publish_service_test.dart", "test/photo_import_flow_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T4 — Generalise SourcePhoto into SessionSource with a kind, name and link

## Why

[ADR-0005](../adr/0005-keep-photos-and-sets-in-one-source-list-with-a-kind.md), [sad §5](../sad.md) naming decision, [data-model.md](../data-model.md) Isar `SessionSource`.

## What

- Rename the file and class (`source_photo.dart` → `session_source.dart`, `SourcePhoto` → `SessionSource`) with `@Name('SourcePhoto')` on the class; add `enum SourceKind { photo, set }` (photo first — stored ordinal), `name`, `url`; JSON gains the three fields, missing `kind` → photo.
- Mechanical rename in every user and test; no behaviour change in the photo path.
- Run `dart run build_runner build --delete-conflicting-outputs`; commit the `.g.dart`.
- Add the legacy-read test (Isar record and JSON without `kind`).

## Definition of Done

**Done when:** `SessionSource` (stored name `SourcePhoto`) has `@enumerated SourceKind kind` with `photo` first, `String? name`, `String? url`; every former `SourcePhoto` use compiles under the new name; a session saved before the change (Isar and JSON) reads back with its photos as `kind == photo`; `build_runner` output committed and `flutter test` passes.

- [ ] legacy-read test passes
- [ ] `flutter test` and `flutter analyze` clean
- [ ] CLAUDE.md greps clean

## Notes

- Touches many files in one lane — any task that also lists these files is serialized after it.
- Keep `fileName` and `takenAt` names (stored format).
