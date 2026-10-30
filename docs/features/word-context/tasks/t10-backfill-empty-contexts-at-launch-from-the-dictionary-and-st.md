---
id: T10
title: "Backfill empty contexts at launch from the dictionary and stored text"
layer: "app"
deps: ["T4", "T9"]
acs: ["AC-12"]
files_hint: ["lib/core/words/context_backfill.dart", "lib/core/providers.dart", "lib/app.dart", "test/context_backfill_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T10 — Backfill empty contexts at launch from the dictionary and stored text

## Why

Derives from [AC-12](../spec.md); see [ADR-0004](../adr/0004-backfill-context-at-launch-from-stored-text-and-the-dictionary.md).

## What

One new service, a provider, the launch hook.

## Definition of Done

- [ ] `ContextBackfill` starts after the collection autofill at launch, in the background
- [ ] sources: define API (typed/set with a definition), stored `FilmDialogue.lines` with a whole-word match (film), the photo's `fullText` (photo)
- [ ] at most 20 words a minute; writes per collection batch through `CollectionStore.update`; marks `contextTried`
- [ ] tests with a fake clock and fake services
- [ ] `flutter analyze` clean

## Notes

—
