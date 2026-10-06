---
id: T5
title: "Drop late lookup results and hide the restore snackbar after a switch"
layer: "ui"
deps: ["T2"]
acs: ["AC-07b", "AC-09"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "test/switch_session_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T5 — Drop late lookup results and hide the restore snackbar after a switch

## Why

Derives from [ADR-0003](../../../features/edit-session-from-history/adr/0003-ignore-lookup-results-that-return-after-a-switch.md), [sad §8 "Async result guard", §11 risk 1](../../../features/edit-session-from-history/sad.md) and [spec AC-07b, AC-09](../../../features/edit-session-from-history/spec.md).

## What

In `word_input_screen.dart`, capture the current session id before each `await` that ends in a row write, and return early after it if the id changed. Paths to cover (enumerate again when implementing):
- dots popup translation load (~`:698`), `_fillWordWithAI` (~`:761`), `_fillWithAI` (~`:832`, `:855`);
- `_fillDefinition` (~`:918`) and the definition-senses load (~`:955`);
- `_processPickedPhoto` (~`:1089`, `:1107`) and lost-photo recovery (~`:215`).

In the session-id `ref.listen` (~`:1444`): when the id changes and no restore is pending, hide a visible RESTORE snackbar.

## Definition of Done

- [x] `test/switch_session_test.dart` (new): with fake services that complete after `switchTo`, a translation, a definition and a photo result each leave the picked session's words unchanged; a restore snackbar visible before the switch is gone after it.
- [x] Existing word-input tests still pass.
- [x] `flutter analyze` adds no issue.

## Notes

Cut-and-paste rule (CLAUDE.md 3): add the guard lines only; do not restructure the handlers. Estimate M because of the number of paths.

## Implementation notes (2026-09-29)

- Guarded paths: dots popup translation load, `_fillWordWithAI`, `_fillWithAI` (both branches, and each
  catch), `_fillDefinition`, `_loadDefinitionSenses`, `_processPickedPhoto` (after `/analyze` and after the
  kept copy resolves: a stale pick deletes the kept photo), `_recoverLostPhoto` (after `retrieveLostData`).
  One helper, `_sessionIdNow`, reads the current session id.
- **Photo result is not covered by the automated test.** `_processPickedPhoto` runs through
  `PhotoScaler.instance` and the image_picker / flutter_image_compress platform channels, which the widget
  harness cannot fake without adding a dev package (CLAUDE.md rule 5). The guard is in place; the check is
  added to T6's device pass. Translation and definition late results, and the RESTORE snackbar, are tested.
- The test keeps one Isar store open for the whole file: `close()` on an Isar the screen watched under
  the fake clock never returns (as in `definition_lightning_test.dart`).
