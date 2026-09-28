---
id: T3
title: "Let the launch rule honour a recent pick"
layer: "app"
deps: ["T1"]
acs: ["AC-09"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "test/word_input_launch_rule_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T3 — Let the launch rule honour a recent pick

## Why

Derives from [ADR-0002](../../../features/edit-session-from-history/adr/0002-remember-the-switch-time-beside-the-current-session-pointer.md) (Rules), [sad §6 flow 2](../../../features/edit-session-from-history/sad.md) and [spec AC-09](../../../features/edit-session-from-history/spec.md).

## What

In `WordInputNotifier.build()`, case 3 ("still warm"): warm if `now − max(prev.lastLocalModifiedAt, await store.switchedAt(prev.sessionId)) < kSessionIdleWindow`. Cases 1, 2, 4 unchanged. Case 3's pointer re-save leaves the pick record alone.

## Definition of Done

- [ ] `test/word_input_launch_rule_test.dart`: a session last edited a week ago but picked 2 minutes ago reopens with no restore offer, on two relaunches in a row; picked 6 minutes ago → a new session plus the restore offer; a pick record for another session id is ignored; a dangling pointer falling back to the newest session ignores the record.
- [ ] Existing launch-rule tests still pass unchanged.
- [ ] `flutter analyze` adds no issue.

## Notes

Shares `word_input_notifier.dart` with T2 → same lane, serialized after T2 or before it (both depend only on T1).
