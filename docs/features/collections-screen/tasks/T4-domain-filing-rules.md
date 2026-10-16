---
id: T4
title: "Add the pure filing rules: tree walks, folder into itself, level renumbering, restore target, days left and expiry"
layer: "domain"
deps: []
acs: ["AC-15", "AC-19", "AC-23", "AC-24", "AC-26"]
files_hint: ["lib/core/services/filing.dart", "test/filing_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T4 — Add the pure filing rules: tree walks, folder into itself, level renumbering, restore target, days left and expiry

## Why

[sad §5](../sad.md#5-building-block-view) `filing.dart`, [sad §8](../sad.md#8-crosscutting-concepts) Time, [ADR-0005](../adr/0005-mark-a-deleted-item-in-place-and-let-a-binned-folders-contents-follow-it.md), [spec §8](../spec.md#8-open-questions) restore position, [screens SCR-08](../screens.md).

## What

- Functions over plain values (ids, parent ids, orders, `DateTime`s, booleans), not Isar classes, so this task does not wait for T2/T5.
- `daysLeft(binnedAt, now)` from calendar days in local time, never below 1; `isExpired(binnedAt, now)`.
- `isEmptyAndUntouched(hasWords, hasSources, hasNotesOrTags, keep)`.

## Definition of Done

**Done when:** Unit tests pass for `filing.dart`: ancestors and descendants of a folder, in-the-bin through an ancestor, a folder into itself or any descendant refused (AC-15), a level renumbered 0..n-1 after an insert or move, the restore target (old folder, else top level; old order when still within the level, else the end), days left 30 on the deletion day and 1 on the last, expiry at exactly binnedAt + 30 × 24 h with a clock moved backwards never erasing early, and the empty-and-untouched rule (AC-19).

- [ ] QG-5's controlled-clock cases (incl. a clock moved backwards) are in `filing_test.dart`
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Pure; the store tasks (T8, T9) call these inside their transactions.
