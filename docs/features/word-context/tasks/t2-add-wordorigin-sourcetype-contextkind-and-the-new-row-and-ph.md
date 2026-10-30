---
id: T2
title: "Add WordOrigin, SourceType, ContextKind and the new row and photo fields"
layer: "infra"
deps: ["T1"]
acs: ["AC-01", "AC-14"]
files_hint: ["lib/core/models/word_origin.dart", "lib/core/models/word_pair.dart", "lib/core/models/session_source.dart", "lib/core/services/collection_store.dart", "test/word_origin_model_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T2 — Add WordOrigin, SourceType, ContextKind and the new row and photo fields

## Why

Derives from [AC-01](../spec.md), [AC-14](../spec.md); see [ADR-0001](../adr/0001-store-the-origin-as-an-embedded-word-origin-on-the-row.md).

## What

New model file, fields on the row and the photo source, generated code, store tests.

## Definition of Done

- [ ] `lib/core/models/word_origin.dart`: `@embedded WordOrigin` (typeOfSource, movieName, season, episode, time, two flags) and enums `SourceType {manuallyEntered, movie, image, set}`, `ContextKind {none, source, ai}` stored by name
- [ ] `WordPair.origin`, `context`, `contextKind`, `contextTried`; `SessionSource.fullText`; defaults for old data
- [ ] every `WordPair` copy path keeps them: `copyWith`/JSON, `CollectionStore.put`, recycle bin restore, new-user-trial put-aside (test per path)
- [ ] `dart run build_runner build --delete-conflicting-outputs` clean
- [ ] `flutter analyze` clean

## Notes

—
