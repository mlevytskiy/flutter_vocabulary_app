---
id: T8
title: "Add DictionaryService and DefinitionResult in the app"
layer: "app"
deps: []
acs: ["AC-05", "AC-06", "AC-07"]
files_hint: ["lib/core/services/dictionary_service.dart", "lib/core/models/definition_result.dart", "lib/core/providers.dart", "lib/core/providers.g.dart", "test/dictionary_service_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T8 — Add DictionaryService and DefinitionResult in the app

## Why

Derives from [ADR-0002](../adr/0002-proxy-dictionary-lookups-through-the-worker.md), [sad §2 override for DefinitionResult, §8 timeouts](../sad.md).

## What

`DictionaryService.define(word)` calls the Worker dictionary route with the app secret and a 6 s timeout, returning a plain `DefinitionResult` (senses, suggestions, or unavailable). Network errors and timeouts become "unavailable", never exceptions. Exposed through `dictionaryServiceProvider`.

## Definition of Done

- [ ] Unit tests with `MockClient`: senses parsed; not-found returns suggestions; a 5xx, malformed body and timeout all return unavailable (AC-07).
- [ ] `build_runner` clean; `flutter analyze` adds no issue.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Contract from ADR-0002 / T4; tests use a mock, so this runs in parallel with T4.
