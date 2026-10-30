---
id: T7
title: "Save photo context, its kind and the full text when a photo is imported"
layer: "app"
deps: ["T2", "T6"]
acs: ["AC-02", "AC-10"]
files_hint: ["lib/core/services/vocab_photo_service.dart", "lib/core/models/vocab_word.dart", "lib/features/words/words_notifier.dart", "test/photo_context_import_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T7 — Save photo context, its kind and the full text when a photo is imported

## Why

Derives from [AC-02](../spec.md), [AC-10](../spec.md); owner B7, B7b.

## What

Photo service, VocabWord, the photo import path.

## Definition of Done

- [ ] `VocabPhotoService.analyzePhoto` is called with `context: true`; `VocabWord` gets `contextSource`; the result carries `fullText`
- [ ] the photo import builds rows with origin image, `context`, `contextKind` (photo → source, ai → ai) and stores `fullText` on the photo's `SessionSource`
- [ ] tests with a mocked client
- [ ] `flutter analyze` clean

## Notes

—
