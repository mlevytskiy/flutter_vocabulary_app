---
id: T11
title: "Wire the From subtitles speed-dial item through parse, request, results and Done"
layer: "wiring"
deps: ["T5", "T7", "T9", "T10"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-05", "AC-05b", "AC-06", "AC-10", "AC-12", "AC-14", "AC-16", "AC-17"]
files_hint: ["lib/features/word_input/widgets/word_input_speed_dial.dart", "lib/features/word_input/word_input_screen.dart", "test/subtitle_import_flow_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T11 — Wire the From subtitles speed-dial item through parse, request, results and Done

## Why

[sad §6 F3 and F4](../sad.md); [spec AC-02 to AC-05b, AC-10, AC-12, AC-14, AC-16, AC-17](../spec.md); [sad §8](../sad.md) Late results and Complete or nothing.

## What

- Add a "From subtitles" item to `word_input_speed_dial.dart` next to "take photo", in the same style.
- `word_input_screen.dart`: a `_runSubtitleImport` method, cut and pasted from the shape of `_processPickedPhoto`, that opens the import dialog, calls `recordUsed`, captures the session id, shows the loading dialog, parses (T5), reads the session words and model, calls the service (T7), closes the loading dialog, drops a result for another session, checks the count, opens the results dialog in subtitle mode (T9), and appends through the notifier's `addAll`.
- Show messages the way the photo flow does (the same snackbar or dialog pattern).

## Definition of Done

**Done when:** Widget tests with a fake service show: the speed-dial item opens the import dialog; Start records the used values only while "Update with each import" is on; the loading dialog appears; a file with no subtitle blocks, 422, 429 and every other failure each close it with the AC-10, AC-14 or AC-12 message and leave the session unchanged; a result for a session that changed since Start is dropped; a list longer than the maximum is rejected as AC-12; Done appends the kept words in order as ordinary word rows with no source photo, and removing everything or closing adds nothing.

- [ ] `flutter test test/subtitle_import_flow_test.dart test/photo_words_test.dart`
- [ ] `dart run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze`
- [ ] `grep -rn "Navigator.push\|MaterialPageRoute\|static final .* instance" lib` finds nothing new
- [ ] lint clean (`flutter analyze` / `tsc`, whichever this task touches)

## Notes

- All dialogs are `showDialog`, with no new route (CLAUDE.md rule 1).
- Photo flow behaviour unchanged (CLAUDE.md rule 3).
