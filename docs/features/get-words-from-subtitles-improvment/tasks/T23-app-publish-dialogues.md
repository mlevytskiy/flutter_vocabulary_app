---
id: T23
title: "Send the session's dialogues and scene-picture declarations when publishing"
layer: "infra"
deps: ["T6", "T12"]
acs: ["AC-20"]
files_hint: ["lib/core/services/session_publish_service.dart", "lib/features/words_table/words_table_screen.dart", "test/session_publish_service_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T23 — Send the session's dialogues and scene-picture declarations when publishing

## Why

[sad §4](../sad.md) choice 5, [ADR-0005](../adr/0005-add-an-imports-rows-and-dialogues-to-the-published-session-automatically.md), good-looking-web ADR-0006.

## What

- `publish` adds `dialogues` for visible dialogues: id, lines, the positions of their word rows in `entries`, and a picture declaration when a scene picture exists.
- After a successful publish or republish, every dialogue and picture is marked delivered, and pictures are handed to the upload outbox (T24).
- A session without dialogues publishes exactly as today.

## Definition of Done

**Done when:** A publish of a session with dialogues sends them with correct entry positions; without dialogues the body is unchanged.

- [ ] service tests for both cases
- [ ] `flutter analyze` clean

## Notes

- None.
