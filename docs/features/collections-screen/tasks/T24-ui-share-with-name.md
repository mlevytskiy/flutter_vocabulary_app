---
id: T24
title: "Send the name with Share link, warn that it is public, and name shared files after it"
layer: "ui"
deps: ["T5"]
acs: ["AC-29", "AC-31", "AC-32"]
files_hint: ["lib/core/services/collection_publish_service.dart", "lib/features/words_table/share_formats.dart", "lib/features/words_table/", "test/collection_publish_service_test.dart", "test/share_formats_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T24 — Send the name with Share link, warn that it is public, and name shared files after it

## Why

[screens SCR-12, SCR-15](../screens.md), [sad §6](../sad.md#6-runtime-view) F12, F13, [ADR-0008](../adr/0008-send-the-collection-name-as-the-shared-pages-title-in-a-nullable-column.md).

## What

- Reuses the existing share sheet and format sheet; one added warning sentence.
- `safeFileName(name)` replaces `\ / : * ? " < > |` and control characters with `-`.

## Definition of Done

**Done when:** Tests show: the publish body carries `title` = the collection's name on create and republish, and dialogue or picture deliveries never send it; SCR-12 default shows "The collection's name, \"<name>\", is visible to anyone with the link."; `safeFileName` turns `Unit 3: phrasal verbs?` into `Unit 3- phrasal verbs-` and `16.10.2026 14:30` into `16.10.2026 14-30`, falls back to `collection`, and every one of the five formats uses it for the file name and the subject, with only the PDF also showing the name as its heading.

- [ ] SCR-12 default and SCR-15 file made covered
- [ ] an old Worker ignoring `title` still publishes (no dependency on T22)
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
