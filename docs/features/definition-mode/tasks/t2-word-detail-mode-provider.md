---
id: T2
title: "Add the persisted word detail mode provider"
layer: "infra"
deps: []
acs: ["AC-01"]
files_hint: ["lib/core/providers.dart", "lib/core/providers.g.dart", "test/word_detail_mode_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T2 — Add the persisted word detail mode provider

## Why

Derives from [sad §4 seed 1 and §8 "Word detail mode"](../sad.md) and [spec AC-01](../spec.md).

## What

Add enum `WordDetailMode { translation, definition, both }` and a `@Riverpod(keepAlive: true)` notifier defaulting to `translation`, persisted under the preferences key `word_detail_mode` (shared_preferences, already a dependency). Never stored on `Session`.

## Definition of Done

- [ ] Unit test: fresh preferences → `translation`; after `set(definition)` a new container reads `definition` (survives restart).
- [ ] Unknown stored value falls back to `translation`.
- [ ] `build_runner` clean; `flutter analyze` adds no issue.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Mirrors `dragModeProvider` (keep-alive) but persists, unlike drag mode.
