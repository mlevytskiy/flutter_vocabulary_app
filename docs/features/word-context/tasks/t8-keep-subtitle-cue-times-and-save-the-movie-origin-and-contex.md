---
id: T8
title: "Keep subtitle cue times and save the movie origin and context on film rows"
layer: "app"
deps: ["T3"]
acs: ["AC-06", "AC-07", "AC-08", "AC-09"]
files_hint: ["lib/core/services/subtitle_parser.dart", "lib/core/services/subtitle_words_service.dart", "lib/features/words/subtitle_import_flow.dart", "test/subtitle_parser_test.dart", "test/subtitle_origin_import_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T8 — Keep subtitle cue times and save the movie origin and context on film rows

## Why

Derives from [AC-06](../spec.md), [AC-07](../spec.md), [AC-08](../spec.md), [AC-09](../spec.md); see [ADR-0003](../adr/0003-keep-subtitle-cue-times-in-the-parser.md).

## What

Parser, words service result, import flow.

## Definition of Done

- [ ] `SubtitleParser.parseTimed` returns `(start, text)`; `parse` = its texts (existing tests unchanged)
- [ ] the subtitle import builds rows with origin movie: name/season/episode from the picked `SubtitleSearchResult`, or the source name + `episodeFromFileName` for a file; `time` from `firstLineTime`
- [ ] context = the line sent for the word, kind source
- [ ] tests for both entry paths
- [ ] `flutter analyze` clean

## Notes

—
