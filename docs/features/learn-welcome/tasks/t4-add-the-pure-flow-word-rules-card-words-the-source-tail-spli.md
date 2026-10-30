---
id: T4
title: "Add the pure flow word rules: card words, the source-tail split, dialog words"
layer: "domain"
deps: ["T1"]
acs: ["AC-05", "AC-06", "AC-13"]
files_hint: ["lib/features/learn/flow/flow_words.dart", "test/learn_flow_words_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T4 — Add the pure flow word rules: card words, the source-tail split, dialog words

## Why

Derives from [AC-05](../spec.md), [AC-06](../spec.md), [AC-13](../spec.md); see [ADR-0002](../adr/0002-split-card-words-on-the-phone-in-list-order.md).

## What

One pure file and its tests.

## Definition of Done

- [ ] `cardWords(rows, boxes, now)`: up to 36 from the first due-or-new row in list order; none → 36 due soonest (list order on ties)
- [ ] `splitGroups(words)`: ≤ 12 in order; a trailing other-source run of ≤ 4 moves on; source key = `sourceId` or typed; `storyGroups` = first 3
- [ ] `dialogWords(words, ratings, mode)`: Easy min(6, ceil(N/2)) ≥ 4, Hard min(12, N); dontRemember first, then hard, then list order
- [ ] tests in `test/learn_flow_words_test.dart` (the decision page's sample runs as a case)
- [ ] `flutter analyze` clean

## Notes

—
