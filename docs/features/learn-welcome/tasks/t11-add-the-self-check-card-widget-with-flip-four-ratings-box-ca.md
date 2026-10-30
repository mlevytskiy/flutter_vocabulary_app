---
id: T11
title: "Add the self-check card widget with flip, four ratings, box captions and the context line"
layer: "ui"
deps: ["T3"]
acs: ["AC-07", "AC-18"]
files_hint: ["lib/features/learn/session/self_check_card.dart", "lib/core/theme/app_decor.dart", "lib/core/theme/themes/", "test/learn_self_check_card_test.dart"]
owner: "implementer agent"
estimate: "M"
status: "done"
---

# T11 — Add the self-check card widget with flip, four ratings, box captions and the context line

## Why

Derives from [AC-07](../spec.md), [AC-18](../spec.md); see [ADR-0006](../adr/0006-one-self-check-card-and-one-set-of-rating-rules.md); was self-check-cards T6.

## What

One widget, theme slots, tests.

## Definition of Done

- [ ] `self_check_card.dart`: front side, Flip, back with word, sound (existing pronunciation buttons), translation, context in italic with "from the source" or "written by AI" + sparkle in `AppDecor.aiAccent`
- [ ] four buttons coloured from new `AppDecor` slots (added to every theme file), enabled after the flip, each with its box caption
- [ ] used later by self-check-cards in exercise sessions and the talk quick check
- [ ] widget tests in two themes
- [ ] `flutter analyze` clean

## Notes

Reads `context`/`contextKind` from word-context T2; until then the context line stays hidden.
