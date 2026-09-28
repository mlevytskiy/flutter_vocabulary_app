---
id: T2
title: "Add WordInputNotifier.switchTo"
layer: "app"
deps: ["T1"]
acs: ["AC-03", "AC-07", "AC-08"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "test/word_input_notifier_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T2 — Add WordInputNotifier.switchTo

## Why

Derives from [ADR-0001](../adr/0001-make-a-history-session-current-by-swapping-the-notifiers-session.md), [sad §6 flow 1](../sad.md) and [spec AC-03, AC-07, AC-08](../spec.md).

## What

`Future<bool> switchTo(String sessionId)` in `word_input_notifier.dart`, modelled on `restorePrevious()`, in this order:
1. Load the picked session; missing → return `false` and touch nothing (AC-08).
2. `flush()` the current session so a word typed within the save delay is kept (AC-07); if the current session is empty and is not the picked one, delete it.
3. Growable copies of `words` / `sources` (as in `build()`), reset `_saveTimer` / `_dirty`.
4. `setCurrentSessionId(picked)` + `setSwitched(picked, now)` (T1). **Do not** stamp `updatedAt` / `lastLocalModifiedAt` (ADR-0002).
5. `restorableSessionId = null`; `state = AsyncData(picked)`; return `true`.

## Definition of Done

- [ ] `test/word_input_notifier_test.dart`: switchTo makes the picked session current with its edit times unchanged and the pick recorded; a pending edit of the left session is saved; an empty left session is deleted; `restorableSessionId` is cleared; an unknown id returns `false` with state, pointer and store unchanged.
- [ ] `flutter analyze` adds no issue; the `CLAUDE.md` greps stay clean.

## Notes

Shares `word_input_notifier.dart` with T3 → same lane, serialized. `restorePrevious()` is not refactored (sad §11 accepted debt).
