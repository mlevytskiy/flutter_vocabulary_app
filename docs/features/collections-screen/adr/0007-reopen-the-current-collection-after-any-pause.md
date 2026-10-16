---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0007 — Reopen the current collection after any pause

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

The launch rule in `WordInputNotifier.build()` starts a new session after a pause of more than 5 minutes and offers the previous one back with a 7-second RESTORE snackbar; a History pick and having the screen open (`switched_*`, `seen_*` records, `markSeen` every 15 s) keep a session warm (edit-session-from-history ADR-0002; owner 2026-10-16). The owner decided that the app no longer starts collections by itself (spec §1, AC-12).

## Decision drivers

- Spec AC-12: exactly one current collection; it changes only when the learner opens or makes one; no background work changes it.
- Spec §7 KPI: 0 new auto-created collections in the 30 days after release.
- ADR-0005: a collection in the bin cannot be current.

## Considered options

1. **Reopen the pointer's collection; remove the time window, RESTORE and the warm-keeping records.**
2. **Keep the window code with an infinite window** — the smallest code change, leaving `markSeen`, the records and the snackbar in place but unreachable.

## Decision outcome

**Chosen:** option 1. Dead code that once made collections by itself is exactly what the KPI guards against; removing it makes the rule readable in a few lines:
1. Nothing stored → create a first collection at the top level (`CollectionStore.create()`).
2. The pointer's collection exists and is not in the bin → reopen it.
3. Otherwise → the newest collection outside the bin by `lastLocalModifiedAt`, or a new one when there is none.

The store also refuses to bin the current collection (AC-21). The `seen_*` and `switched_*` keys are removed once at startup.

Supersedes edit-session-from-history ADR-0002.

## Consequences

**Positive**
- The current collection is the learner's choice, nothing else.
- `markSeen`'s 15-second timer and the RESTORE snackbar disappear from the main screen.

**Negative**
- `word_input_launch_rule_test.dart` and architecture.md §3 are rewritten.

**Neutral**
- An empty collection that was not kept is still erased when the learner leaves it (AC-19), so the old "reuse the empty one" case is no longer needed.

## Links

- Spec: [[../spec.md]] §1 decision 4, US-04, AC-12, AC-21
- SAD: [[../sad.md]] §4
- Related ADR: supersedes edit-session-from-history [[../../edit-session-from-history/adr/0002-remember-the-switch-time-beside-the-current-session-pointer]]
