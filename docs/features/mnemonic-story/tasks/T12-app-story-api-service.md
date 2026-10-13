---
id: T12
title: "Add the app's story service for the Worker's story routes"
layer: "infra"
deps: ["T10", "T7", "T9"]
acs: ["AC-12", "AC-13", "AC-19"]
files_hint: ["lib/core/services/story_api_service.dart", "lib/core/models/offered_ai.dart", "lib/core/providers.dart", "test/story_api_service_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T12 — Add the app's story service for the Worker's story routes

## Why

[sad §5](../sad.md) `story_api_service.dart`; [ADR-0004](../adr/0004-serve-the-offered-ai-list-with-prices-from-the-worker.md); the Worker routes from T7 and T9.

## What

- `StoryApiService` over `http` with `x-app-secret` from `VocabApiConfig`, like `vocab_photo_service.dart`: `offeredAis()`, `group(words, keep)`, `startRun(...)`, `status(runIds)`, `redo(...)`, `picture(runId, attempt)`. Refusals are typed (`notOffered`, `dayLimit`, `rateLimited`).
- `OfferedAi` / `AiChoice` models. Providers `storyApiServiceProvider` and `offeredAisProvider` (fetch + cache in `shared_preferences`, falling back to the cache or the defaults) and a persisted `aiChoiceProvider` with the fallback to defaults (AC-13).

## Definition of Done

**Done when:** Each service method maps the Worker's answers and refusal codes to typed results, and `offeredAisProvider` uses the cached list when the fetch fails, tested with a fake HTTP client in `test/story_api_service_test.dart`.

- [ ] no `static instance`, the service comes from a provider
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- The JSON shapes are the Worker's from T7 and T9. If `/sdd:api` runs first, follow `contracts/openapi.yaml`.
