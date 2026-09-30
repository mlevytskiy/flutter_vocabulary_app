---
id: T7
title: "Call POST /subtitles/words from the app and map every answer to its message"
layer: "infra"
deps: ["T6"]
acs: ["AC-10", "AC-12", "AC-14", "AC-21"]
files_hint: ["lib/core/services/subtitle_words_service.dart", "lib/core/providers.dart", "test/subtitle_words_service_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T7 — Call POST /subtitles/words from the app and map every answer to its message

## Why

[contracts/openapi.yaml](../contracts/openapi.yaml); [api-sync-report.md](../contracts/api-sync-report.md) App error mapping; [sad §8](../sad.md) Error handling.

## What

- `lib/core/services/subtitle_words_service.dart`, following `vocab_photo_service.dart`: `pickWords(lines, purpose, level, maximum, model, sessionWords)` → `SubtitleWordsResult(words, model, aiDuration, inputTokens, outputTokens)`, throwing a typed `SubtitleWordsException` of kind `noEnglish`, `tooManyImports` or `notPicked`.
- A 240 s timeout; base URL and secret from `VocabApiConfig`.
- Register `subtitleWordsServiceProvider` in `lib/core/providers.dart`.

## Definition of Done

**Done when:** Tests with `http`'s `MockClient` show a 200 parsed into `VocabWord`s plus model, AI time and token counts; 422 → the no-English error; any 429 → the too-many-imports error; 400, 401, 413, 502, other statuses, a socket error, non-JSON and a 240 s timeout → the could-not-pick error; the request sends `x-app-secret` and the contract's camelCase body.

- [ ] `flutter test test/subtitle_words_service_test.dart`
- [ ] `flutter analyze`
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- `MockClient` comes from `package:http/testing.dart`, part of `http`, so no new package (CLAUDE.md rule 5).
- Reuses `VocabWord` (no new domain model).
