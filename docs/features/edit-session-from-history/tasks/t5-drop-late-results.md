---
id: T5
title: "Drop late lookup results and hide the restore snackbar after a switch"
layer: "ui"
deps: ["T2"]
acs: ["AC-07b", "AC-09"]
files_hint: ["lib/features/word_input/word_input_screen.dart", "test/switch_session_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T5 — Drop late lookup results and hide the restore snackbar after a switch

## Why

Derives from [ADR-0003](../adr/0003-ignore-lookup-results-that-return-after-a-switch.md), [sad §8 "Async result guard", §11 risk 1](../sad.md) and [spec AC-07b, AC-09](../spec.md).

## What

In `word_input_screen.dart`, capture the current session id before each `await` that ends in a row write, and return early after it if the id changed. Paths to cover (enumerate again when implementing):
- dots popup translation load (~`:698`), `_fillWordWithAI` (~`:761`), `_fillWithAI` (~`:832`, `:855`);
- `_fillDefinition` (~`:918`) and the definition-senses load (~`:955`);
- `_processPickedPhoto` (~`:1089`, `:1107`) and lost-photo recovery (~`:215`).

In the session-id `ref.listen` (~`:1444`): when the id changes and no restore is pending, hide a visible RESTORE snackbar.

## Definition of Done

- [ ] `test/switch_session_test.dart` (new): with fake services that complete after `switchTo`, a translation, a definition and a photo result each leave the picked session's words unchanged; a restore snackbar visible before the switch is gone after it.
- [ ] Existing word-input tests still pass.
- [ ] `flutter analyze` adds no issue.

## Notes

Cut-and-paste rule (CLAUDE.md 3): add the guard lines only; do not restructure the handlers. Estimate M because of the number of paths.
