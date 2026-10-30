---
id: T9
title: "Set the dictionary example as context when a definition is filled or picked"
layer: "app"
deps: ["T2", "T5"]
acs: ["AC-02", "AC-11"]
files_hint: ["lib/core/models/definition_result.dart", "lib/core/services/dictionary_service.dart", "lib/features/words/words_notifier.dart", "test/definition_context_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T9 — Set the dictionary example as context when a definition is filled or picked

## Why

Derives from [AC-02](../spec.md), [AC-11](../spec.md); owner B8, proxy Q13.

## What

Definition result parsing and the definition fill path.

## Definition of Done

- [ ] `DefinitionResult` exposes the example of each sense (from "definition: …\nexample: …")
- [ ] filling or picking a definition on a typed or set row sets `context` to that sense's example, kind source; a Quizlet definition is never copied into context
- [ ] tests in `test/definition_context_test.dart`
- [ ] `flutter analyze` clean

## Notes

—
