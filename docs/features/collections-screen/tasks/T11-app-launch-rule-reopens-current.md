---
id: T11
title: "Make launch and resume reopen the current collection, sweep the bin, and drop the RESTORE offer"
layer: "app"
deps: ["T9"]
acs: ["AC-12", "AC-26"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "lib/features/word_input/word_input_screen.dart", "lib/core/services/collection_store.dart", "test/word_input_launch_rule_test.dart", "test/session_seen_timer_test.dart"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T11 — Make launch and resume reopen the current collection, sweep the bin, and drop the RESTORE offer

## Why

[ADR-0007](../adr/0007-reopen-the-current-collection-after-any-pause.md), [sad §6](../sad.md#6-runtime-view) F4, [screens SCR-01](../screens.md) (restore offer removed).

## What

- Remove `kSessionIdleWindow`, cases 2–4, `restorableSessionId`, `restorePrevious`, `markSeen` and its timer, `setSwitched`/`switchedAt`/`setSeen`/`seenAt`.
- Remove the RESTORE snackbar from the main screen; add an app-lifecycle resume hook that calls `sweepBin` and re-checks the pointer.
- Replace `word_input_launch_rule_test.dart` with the new cases; delete the seen-timer test (its behaviour is gone).

## Definition of Done

**Done when:** Launch-rule tests show: after any pause the pointer's collection reopens with no new collection and no RESTORE snackbar; a missing or binned pointer falls back to the newest collection outside the bin, or a new one when none; only an empty store creates a first collection; `sweepBin` runs on open and on resume; the `switched_*` and `seen_*` keys are removed once at startup and never written.

- [ ] one test per F4 branch
- [ ] no RESTORE text anywhere in `lib/`
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

Supersedes edit-session-from-history ADR-0002/ADR-0003 behaviour; T26 records that in the docs.
