---
id: T5
title: "Strip SRT and VTT files to dialogue lines in pure Dart"
layer: "domain"
deps: []
acs: ["AC-08", "AC-10"]
files_hint: ["lib/core/services/subtitle_parser.dart", "test/subtitle_parser_test.dart", "test/fixtures/subtitles/"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T5 — Strip SRT and VTT files to dialogue lines in pure Dart

## Why

[ADR-0002](../adr/0002-strip-subtitles-in-the-app-and-send-dialogue-lines.md); [sad §6 F3](../sad.md) first `alt`; [contracts/openapi.yaml](../contracts/openapi.yaml) `lines` bounds.

## What

- `lib/core/services/subtitle_parser.dart`: `SubtitleParser.parse(String text, {required String extension})` → a list of lines, or a typed "no subtitle blocks" result. Handles BOM, CRLF, VTT `WEBVTT` header, `NOTE` and `STYLE` blocks, and SRT/VTT tags such as `<i>` and `{\an8}`.
- Test fixtures with placeholder dialogue only (no copyrighted film text beyond a line or two).

## Definition of Done

**Done when:** Unit tests over SRT and VTT fixtures show cue numbers, timings, tags, [captions], (captions), NAME: labels and music marks removed, lines over 200 chars split, empty or non-subtitle input reported as "no subtitle blocks", and a 1 MB fixture stripped to lines totalling ≤ 1,048,576 UTF-8 bytes.

- [ ] `flutter test test/subtitle_parser_test.dart`
- [ ] `flutter analyze` clean
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- Pure Dart with no package. Exposed through a provider in T11 only if the screen needs it; a plain class is fine (CLAUDE.md rule 2 concerns services with state or I/O).
