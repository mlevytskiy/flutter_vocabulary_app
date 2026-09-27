---
id: T16
title: "Publish definitions and the detail mode"
layer: "app"
deps: ["T1", "T2", "T5"]
acs: ["AC-16", "AC-19"]
files_hint: ["lib/core/services/session_publish_service.dart", "lib/features/words_table/words_table_screen.dart", "test/session_publish_service_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T16 — Publish definitions and the detail mode

## Why

Derives from [ADR-0004](../adr/0004-record-the-detail-mode-in-the-published-session.md) and [spec AC-16, AC-19](../spec.md).

## What

The publish request sends each filled row with `definition` and the session-level `detail` from the current mode (hidden fields sent empty); a "definition too long" refusal shows the Worker's message naming the word.

## Definition of Done

- [ ] MockClient tests: body carries definitions and `detail` per mode; the too-long refusal surfaces the word in the error.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Release after T5 is deployed (ADR-0004).
