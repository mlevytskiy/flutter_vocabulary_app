---
id: T17
title: "Open the flow from Learn and remove the Learn sheet, the split checkbox and the group line"
layer: "ui"
deps: ["T12", "T13"]
acs: ["AC-01", "AC-17"]
files_hint: ["lib/router/routes.dart", "lib/features/words_table/widgets/learn_share_bar.dart", "lib/features/learn/entry/learn_sheet.dart", "lib/features/learn/widgets/group_pager.dart", "test/learn_entry_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T17 — Open the flow from Learn and remove the Learn sheet, the split checkbox and the group line

## Why

Derives from [AC-01](../spec.md), [AC-17](../spec.md); owner A1, A14.

## What

Entry button, routes, removals.

## Definition of Done

- [ ] `LearnFlowRoute(collectionId)` in `routes.dart`; Learn on the Words screen goes there
- [ ] remove `learn_sheet.dart`, the split checkbox and its preference, the group line; Learn settings stays (gear in the warm-up)
- [ ] update or remove tests that covered the sheet
- [ ] widget tests for entry
- [ ] `flutter analyze` clean

## Notes

—
