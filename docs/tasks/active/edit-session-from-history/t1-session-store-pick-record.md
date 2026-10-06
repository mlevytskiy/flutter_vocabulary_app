---
id: T1
title: "Store the pick record beside the current-session pointer"
layer: "infra"
deps: []
acs: ["AC-09"]
files_hint: ["lib/core/services/session_store.dart", "test/session_store_test.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T1 — Store the pick record beside the current-session pointer

## Why

Derives from [ADR-0002](../../../features/edit-session-from-history/adr/0002-remember-the-switch-time-beside-the-current-session-pointer.md) (Rules) and [sad §5, §8](../../../features/edit-session-from-history/sad.md); feeds [spec AC-09](../../../features/edit-session-from-history/spec.md).

## What

In `SessionStore`, next to `current_session_id`:
- `Future<void> setSwitched(String sessionId, DateTime at)` — writes the pick record (session id + time) to `shared_preferences`.
- `Future<DateTime?> switchedAt(String sessionId)` — the stored time only if the record's id equals `sessionId`, else `null`. Bad or missing data → `null` (the store never throws).
- Nothing clears the record; `setCurrentSessionId` is unchanged.

## Definition of Done

- [x] `test/session_store_test.dart`: after `setSwitched(A, t)`, `switchedAt(A) == t` and `switchedAt(B) == null`; the record survives reopening the store; a corrupt value reads as `null`.
- [x] `flutter analyze` adds no issue; the `CLAUDE.md` greps stay clean.

## Notes

No Isar field and no `build_runner` change (ADR-0002, CLAUDE.md rule 5).
