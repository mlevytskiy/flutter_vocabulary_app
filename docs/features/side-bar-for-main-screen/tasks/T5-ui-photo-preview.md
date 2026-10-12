---
id: T5
title: "Show a photo from the kept file at preview size, with a not-available placeholder"
layer: "ui"
deps: []
acs: ["AC-09"]
files_hint: ["lib/features/word_input/photo_panel/photo_preview.dart", "test/photo_preview_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T5 — Show a photo from the kept file at preview size, with a not-available placeholder

## Why

[spec AC-09](../spec.md), [sad §4 "Previews" and §8 "Images and memory"](../sad.md), sad §6 Flow 1 and Flow 5.

## What

- `PhotoPreview(source, width)` reads bytes through the `SourcePhotoStore` provider after the first frame, decodes with `Image.memory(cacheWidth: …)` like the words table's `_PhotoStack` (copied pattern, not imported), and falls back to the placeholder on `null` or `errorBuilder`.
- The placeholder widget is given by the look (T6) so each variant draws its own; a plain default is used until then.

## Definition of Done

**Done when:** `photo_preview_test.dart` passes: a readable source decodes with `cacheWidth` = width × device pixel ratio, and a `null` read or a decode error shows the "not available" placeholder while the other previews still show.

- [ ] test: fake store returning bytes, `null`, and corrupt bytes
- [ ] test: decode width follows the device pixel ratio
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Nothing imported from the words table feature (architecture.md §2 rule 3).
