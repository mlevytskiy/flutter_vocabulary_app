---
id: T14
title: "Add the word-groups notifier that groups a session and keeps its selection"
layer: "app"
deps: ["T11", "T12"]
acs: ["AC-01", "AC-02", "AC-02b", "AC-03", "AC-04", "AC-05", "AC-11"]
files_hint: ["lib/core/story/word_groups_notifier.dart", "test/word_groups_notifier_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T14 — Add the word-groups notifier that groups a session and keeps its selection

## Why

[sad §5](../sad.md) `word_groups_notifier.dart`; [sad §6](../sad.md) S-01, S-02.

## What

- `@riverpod WordGroupsNotifier(sessionId?)`: reads the current session or a History session. `ensureGrouped()` runs `planGrouping`, then either saves the local groups or calls `group(...)` and `applySplit`. Its states: idle, grouping, failed ("Could not group your words"), waiting(N).
- `select(groupId)` persists `selectedGroupId`. A History session is saved without becoming current (AC-11).
- After grouping or selection, if the selected group has no story and no run, it calls `StoryRunTracker.startFor(group)` through its provider (T15). Until T15 lands, a no-op hook.

## Definition of Done

**Done when:** With a fake service and an in-memory store, `test/word_groups_notifier_test.dart` shows grouping runs once per change and not again unchanged, failures and invalid splits give the failed state, waiting words give waiting(N), selection persists, and a History session's groups never touch the current session.

- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` and `flutter test` pass, and the CLAUDE.md greps (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`) find nothing new

## Notes

- Lives in `lib/core/story/` so both the Words screen and the learn page use it (rule 3).
