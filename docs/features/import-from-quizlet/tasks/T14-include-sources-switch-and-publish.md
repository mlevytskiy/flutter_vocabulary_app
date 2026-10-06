---
id: T14
title: "Publish photos and sets behind one \"Include sources (N)\" switch"
layer: "app"
deps: ["T4", "T2"]
acs: ["AC-12", "AC-15"]
files_hint: ["lib/core/services/session_publish_service.dart", "lib/core/services/photo_upload_service.dart", "lib/features/words_table/words_table_screen.dart", "test/session_publish_service_test.dart", "test/words_table_test.dart", "test/photo_upload_service_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T14 — Publish photos and sets behind one "Include sources (N)" switch

> **Superseded in part by [T18](T18-owner-review-changes.md) (owner review 2026-10-06):** the switch is "Include photos (N)" again and covers photos only; set sources are always sent. The payload, the removed cap and the photo-only upload stay as built here.

## Why

spec AC-12, AC-15, §6 sources per published session; [ADR-0006](../adr/0006-publish-set-sources-in-the-sources-list-with-a-kind.md); [sad §6 F4](../sad.md).

## What

- Publish payload: sources with `kind`, `name`, `url`; remove `maxSources`.
- Upload: skip non-photo sources.
- Share sheet: rename the switch and its count; the thumbnail stack shows photos (a set's tile follows the shared page's choice in T3).

## Definition of Done

**Done when:** The share sheet reads "Include sources (N)" counting photos and sets that still have a word row, on by default with the 30-day notice; with it on, the publish sends every counted source in order with its kind (a set with name and plain link) and no 10-source cap, the background upload sends bytes for photos only; with it off, no source and no `sourceId` are sent; service and widget tests cover both.

- [ ] tests pass, including 12 photos + 3 sets all sent in order
- [ ] `flutter analyze` clean

## Notes

- Contract must match T2 exactly; depends on it so the shapes are fixed first.
