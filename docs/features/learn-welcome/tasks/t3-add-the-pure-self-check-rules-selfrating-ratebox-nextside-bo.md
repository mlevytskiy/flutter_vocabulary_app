---
id: T3
title: "Add the pure self-check rules: SelfRating, rateBox, nextSide, box labels"
layer: "domain"
deps: ["T2"]
acs: ["AC-07", "AC-08"]
files_hint: ["lib/features/learn/session/self_check.dart", "test/learn_self_check_rules_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T3 — Add the pure self-check rules: SelfRating, rateBox, nextSide, box labels

## Why

Derives from [AC-07](../spec.md), [AC-08](../spec.md); moved here from self-check-cards T2 ([ADR-0006](../adr/0006-one-self-check-card-and-one-set-of-rating-rules.md)).

## What

One pure file beside `leitner.dart`.

## Definition of Done

- [ ] `SelfRating {dontRemember, hard, medium, easy}`; `rateBox(WordBox? box, rating, now, {afterMistake})` (Easy after a mistake = Medium, for self-check-cards)
- [ ] up at most once a calendar day via `lastUpDay`; due = start of today + `intervalDays`
- [ ] `nextSide(box)`: '' or en → uk, uk → en; `boxLabel(box, rating)` for the button captions
- [ ] tests in `test/learn_self_check_rules_test.dart`
- [ ] `flutter analyze` clean

## Notes

—
