---
id: T13
title: "Add the flow pager: cards, story picture pages, the wait page and the card counter"
layer: "ui"
deps: ["T10", "T11"]
acs: ["AC-07", "AC-10", "AC-11"]
files_hint: ["lib/features/learn/flow/learn_flow_screen.dart", "lib/features/learn/flow/story_page.dart", "test/learn_flow_screen_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "todo"
---

# T13 — Add the flow pager: cards, story picture pages, the wait page and the card counter

## Why

Derives from [AC-07](../spec.md), [AC-10](../spec.md), [AC-11](../spec.md); owner A9 (5 cards), A17, proxy Q8.

## What

Flow screen and its pages.

## Definition of Done

- [ ] `learn_flow_screen.dart`: warm-up, then one `PageView` driven by the notifier's slots
- [ ] story page = the picture alone, full screen; wait page = "Writing your story…" with the run's progress and "Skip, show it later"
- [ ] "Card N of M" counter on card pages
- [ ] widget tests with a fake notifier state
- [ ] `flutter analyze` clean

## Notes

—
