---
id: T24
title: "Append an import's rows and dialogues, and upload scene pictures, to the shared link automatically"
layer: "app"
deps: ["T7", "T17", "T20", "T23"]
acs: ["AC-20"]
files_hint: ["lib/core/dialogues/dialogue_push.dart", "lib/core/providers.dart", "lib/app.dart", "test/dialogue_push_test.dart"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T24 — Append an import's rows and dialogues, and upload scene pictures, to the shared link automatically

## Why

[sad §4](../sad.md) choice 5, [ADR-0005](../adr/0005-add-an-imports-rows-and-dialogues-to-the-published-session-automatically.md), [sad §6](../sad.md) critical flow 1.

## What

- A `keepAlive` `dialoguePushProvider`: for each session with a link, sends every pending import (its rows still alive among `importRowIds` and its dialogues that still have words) to the append route with the edit token and `importId`; on success marks them delivered and removes hidden dialogues.
- Uploads each pending scene picture after the tracker collects it.
- Retries with growing pauses while the app runs, and once on app start (read once in `app.dart`, like the tracker). `gone` or a refused token stops retrying and marks the item dropped (§11).

## Definition of Done

**Done when:** A pending import is delivered once even across an app restart, a picture is uploaded after collection, and an expired link stops the retries.

- [ ] tests with a fake HTTP client: deliver, repeat after restart (same import id), all words deleted before delivery (hidden dialogue removed after), picture upload, gone
- [ ] `flutter analyze` clean

## Notes

- L: at the one-day limit.
