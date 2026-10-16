---
id: T13
title: "Deliver late translation, photo reading, Quizlet and subtitle results into the collection they started in"
layer: "app"
deps: ["T7", "T12"]
acs: ["AC-11", "AC-27"]
files_hint: ["lib/features/word_input/word_input_notifier.dart", "lib/features/word_input/quizlet_import_flow.dart", "lib/features/word_input/subtitle_import_flow.dart", "lib/features/word_input/word_input_screen.dart", "test/late_results_test.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T13 — Deliver late translation, photo reading, Quizlet and subtitle results into the collection they started in

## Why

[ADR-0006](../adr/0006-deliver-late-results-into-their-own-collection-through-an-atomic-store-update.md) (supersedes the "drop a result for another session" rule of import-from-quizlet and edit-session-from-history ADR-0003), [sad §6](../sad.md#6-runtime-view) F3 late-result branch.

## What

- Where a flow checks `currentSessionId() != startedIn` and drops, route the result to `store.update(startedIn, …)` instead.
- In the notifier, a lookup whose row's collection is no longer current updates that collection by id.

## Definition of Done

**Done when:** Tests show that a translation lookup, a photo reading, a Quizlet import and a subtitle import started in collection A and finishing after the learner opened B are written into A through `CollectionStore.update` (also when A is in the bin), never appear in B, and are dropped and logged when A was erased for good.

- [ ] one test per producer: switch mid-flight, result lands in A
- [ ] A erased mid-flight: nothing written
- [ ] `flutter analyze` clean and `tool/test.sh changed` green

## Notes

—
