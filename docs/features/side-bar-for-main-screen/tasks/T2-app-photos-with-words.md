---
id: T2
title: "Derive the current session's photos with words"
layer: "app"
deps: []
acs: ["AC-02", "AC-03", "AC-15", "AC-16"]
files_hint: ["lib/features/word_input/photo_panel/photos_with_words.dart", "lib/features/word_input/photo_panel/photos_with_words.g.dart", "test/photos_with_words_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T2 — Derive the current session's photos with words

## Why

[spec AC-02, AC-03, AC-15, AC-16](../spec.md), [sad §4 "Photos with words"](../sad.md), sad §6 Flow 3.

## What

- `photosWithWordsProvider` (`@riverpod`) watches `wordInputNotifierProvider` and returns, in one pass over the rows, the current session's sources of kind photo that at least one row links to by `sourceId`, each with its linked row ids, in the order of `Session.sources` (oldest first).
- A row whose word is cleared does not count as linked (AC-15). Quizlet sets are never listed.

## Definition of Done

**Done when:** `photos_with_words_test.dart` passes: only photo sources of the current session with at least one linked row are listed, in `Session.sources` order, with their row ids; a typed, Quizlet-only or emptied session gives an empty list; deleting a photo's last row or clearing its word removes it at once.

- [ ] test: typed session, Quizlet-only session, mixed session, two photos where one loses its last row, a cleared word, a new photo added
- [ ] test: provider rebuilds after a notifier change without a manual refresh
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- Reads only the current session, which makes AC-16 hold by construction.
- Run `dart run build_runner build --delete-conflicting-outputs` for the `.g.dart` part.
