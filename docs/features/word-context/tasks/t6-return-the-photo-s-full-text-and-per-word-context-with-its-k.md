---
id: T6
title: "Return the photo's full text and per-word context with its kind from /analyze"
layer: "ports"
deps: []
acs: ["AC-10"]
files_hint: ["vocab-photo-api/src/index.ts", "vocab-photo-api/test/analyze-context.test.ts"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T6 — Return the photo's full text and per-word context with its kind from /analyze

## Why

Derives from [AC-10](../spec.md); see [ADR-0002](../adr/0002-get-photo-context-from-the-same-analyze-call.md).

## What

Worker prompt, parser and tests.

## Definition of Done

- [ ] `index.ts`: with `context=true` the prompt adds `full_text` and per word `context_source` (`photo` / `ai`), writing a sentence itself on exercise sheets or word lists
- [ ] the validator accepts old answers without the new fields
- [ ] vitest cases for running text, an exercise sheet and an old-shape answer
- [ ] deploy noted for the owner (not run by the task)
- [ ] `flutter analyze` clean and `npx vitest run` green in `vocab-photo-api`

## Notes

—
