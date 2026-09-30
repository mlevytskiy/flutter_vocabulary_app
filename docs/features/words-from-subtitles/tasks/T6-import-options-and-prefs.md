---
id: T6
title: "Add the import option types, the price table and the import preferences notifier"
layer: "domain"
deps: []
acs: ["AC-01", "AC-05", "AC-05b", "AC-09", "AC-21"]
files_hint: ["lib/core/models/subtitle_import_options.dart", "lib/core/providers.dart", "test/subtitle_import_prefs_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T6 — Add the import option types, the price table and the import preferences notifier

## Why

[data-model.md](../data-model.md) Device preferences; [sad §6 F2 and F3 `opt`](../sad.md); [ADR-0004](../adr/0004-let-the-learner-pick-the-subtitle-model-from-a-worker-allow-list.md) for the models and prices.

## What

- `lib/core/models/subtitle_import_options.dart`: `ImportPurpose` and `EnglishLevel` enums with their wire names from the contract, and `SubtitleModel` with its Anthropic id, display name and a dated per-million-token price table for the cost line.
- In `lib/core/providers.dart`, a `@riverpod` `SubtitleImportPrefs` notifier following `WordDetailModeNotifier`: `setPurpose`, `setLevel`, `setMaximum`, `setUpdateEachImport`, `setModel`, and `recordUsed(purpose, level, maximum)`.

## Definition of Done

**Done when:** Unit tests show the notifier reads the five keys from data-model.md with first-launch defaults (understand this film, B2, 20, update on, Sonnet 5), falls back to the default for a missing or unknown stored value, refuses a maximum outside 1–100, and `recordUsed` overwrites purpose, level and maximum only while "Update with each import" is on; `build_runner` and `flutter analyze` are clean.

- [ ] `dart run build_runner build --delete-conflicting-outputs`
- [ ] `flutter test test/subtitle_import_prefs_test.dart`
- [ ] `flutter analyze`
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- Follows the **amended** preferences model (sad §6 notes, data-model.md). Spec AC-05 still has the old wording until `/sdd:clarify` runs.
- Shares `providers.dart` with T7 (lane serialized).
