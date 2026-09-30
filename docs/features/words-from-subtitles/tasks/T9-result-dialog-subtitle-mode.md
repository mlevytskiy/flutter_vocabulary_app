---
id: T9
title: "Rename Description to Definition and add the info line and empty message to the results dialog"
layer: "ui"
deps: ["T6"]
acs: ["AC-18", "AC-20", "AC-21"]
files_hint: ["lib/features/word_input/widgets/vocab_result_dialog.dart", "test/photo_words_test.dart", "test/vocab_result_dialog_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T9 — Rename Description to Definition and add the info line and empty message to the results dialog

## Why

[spec AC-18, AC-20, AC-21](../spec.md); [sad §5](../sad.md) (`vocab_result_dialog.dart` + optional info line and empty message).

## What

- Add optional named parameters to `showVocabResultDialog` (the info line and a subtitle-mode empty message) so existing photo call sites compile unchanged.
- Change the label text only; keep the layout and styles.

## Definition of Done

**Done when:** Widget tests show "Definition" for photo and subtitle words; the photo dialog otherwise unchanged (its timing lines still shown); in subtitle mode no photo timing line, one "<model> · <time> · ≈ $<cost>" line computed from the T6 price table, and "No new words above your level in these subtitles." when the list is empty, with Done returning an empty list.

- [ ] `flutter test test/vocab_result_dialog_test.dart test/photo_words_test.dart`
- [ ] `flutter analyze`
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- Adding optional parameters is not a breaking change, so there is no compile-coupled pair.
