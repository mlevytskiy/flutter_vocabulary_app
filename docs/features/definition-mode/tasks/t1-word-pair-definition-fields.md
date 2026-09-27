---
id: T1
title: "Add definition fields and the filled-row helper to WordPair"
layer: "domain"
deps: []
acs: ["AC-11", "AC-12", "AC-13"]
files_hint: ["lib/core/models/word_pair.dart", "lib/core/models/word_pair.g.dart", "test/word_pair_test.dart", "test/session_store_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T1 — Add definition fields and the filled-row helper to WordPair

## Why

Derives from [ADR-0003](../adr/0003-store-definition-text-and-senses-on-the-word-row.md), [sad §8 "Filled" row](../sad.md) and [spec AC-12, AC-13](../spec.md).

## What

Add `definition` (String, default `''`), `definitionOptionsJson` (String?), `definitionMarkedFilled` (bool) to the embedded `WordPair`, with `fromJson` / `toJson` / `copy` and a `definitionOptions` getter/setter mirroring `translationOptions`. Add one helper `isFilled` = non-empty word and (translation or definition); keep `isValid`'s old meaning only where nothing else reads it, or migrate its readers in the tasks that own them. Regenerate with `build_runner`.

## Definition of Done

- [ ] Unit tests: JSON round trip and `copy()` keep all three new fields; defaults are empty/null/false.
- [ ] Session-store test: a session saved before this change loads with empty definitions and no error (AC-13).
- [ ] Unit test: `isFilled` is true for word+definition with no translation, and for word+translation with no definition (AC-12).
- [ ] `dart run build_runner build --delete-conflicting-outputs` clean; `flutter analyze` adds no issue.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

isar_community is pinned to 3.3.0-dev.1 — regenerate, never upgrade. Adding fields with defaults is non-breaking for stored sessions.
