---
id: T4
title: "Add the red Edit button and question to the History words screen"
layer: "ui"
deps: ["T2"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-06", "AC-08"]
files_hint: ["lib/features/words_table/words_table_screen.dart", "test/words_table_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T4 — Add the red Edit button and question to the History words screen

## Why

Derives from [spec AC-01..AC-04, AC-06, AC-08](../spec.md) and [sad §5, §8 Navigation](../sad.md).

## What

In `WordsTableScreen`:
- `floatingActionButton`: a round red `FloatingActionButton` with `Icons.edit` (tooltip "Edit"), shown only when `widget.sessionId != null` **and** it differs from the notifier's current session id (AC-06). Reuses the Material FAB — no new component.
- Tap → `AlertDialog` "Do you want to edit this list of words?" with **No** / **Yes**. No → close only (AC-04).
- Yes → `await ref.read(wordInputNotifierProvider.notifier).switchTo(id)`; `true` → `const WordInputRoute().go(context)` (stack replaced, Back leaves the app — AC-03); `false` → snackbar "This session can't be opened for editing", stay (AC-08).

## Definition of Done

- [ ] `test/words_table_test.dart`: no button for the current session or with no sessionId; button for a past session; No leaves the screen and current session unchanged; Yes shows the main screen with the picked words; a missing session shows the snackbar and stays.
- [ ] Nothing else on the words screen changes (CLAUDE.md rule 3).
- [ ] `flutter analyze` adds no issue; `grep Navigator.push` stays clean.

## Notes

Runs in parallel with T5 (disjoint files). Visual check is in T6.
