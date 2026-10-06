---
status: Accepted
owner: "Maksym"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-29"
feature_size: "XS"
ticket: "spec US-01..US-03"
---

# 0001 — Make a History session current by swapping the notifier's session

- **Status:** Accepted
- **Date:** 2026-09-29
- **Deciders:** Maksym, Claude (design, easy depth)

## Context

The learner wants to keep editing a past session opened from History (spec US-01..US-03). The main screen edits whatever `WordInputNotifier` holds, and it already rebuilds its rows whenever the notifier's session id changes — that is how RESTORE works today (`restorePrevious()`).

## Decision drivers

- Spec §2: switching never loses a word; carry on with a past session in two taps.
- Spec §6: switch ≤ 1 s; no visual change beyond the button and question (CLAUDE.md rule 3).
- CLAUDE.md rule 5: no new models or packages.

## Considered options

1. **Swap the notifier's session (`switchTo`)** — generalise `restorePrevious()` to any stored session; the main screen reloads through its existing listener.
Only one live option remained once spec §3 set the scope; the two below are recorded because a reader will ask about them, not as contenders.

2. **Make the History words screen editable** — excluded by spec §3 non-goal 1 (the History words screen stays read-only).
3. **Copy the past session's words into the current session** — excluded by spec §3 non-goal 2 (no merging).

## Decision outcome

**Chosen:** Option 1. It reuses a path that already works and is tested, adds one notifier method and a button, and keeps one editing surface. Options 2 and 3 are out of scope per spec §3; option 2 would also duplicate the main screen's editing tools and break rule 3.

## Consequences

**Positive**
- One small method plus UI; the main screen needs no new reload logic.
- The picked session keeps its id, so a later re-share overwrites the same link (good-looking-web ADR-0008).

**Negative**
- `switchTo` and `restorePrevious` overlap until someone folds one into the other.

**Neutral**
- Order matters: load the picked session first, then flush or drop the current one (spec AC-08).

## Links

- Spec: [[../spec.md]] US-01..US-03, AC-03, AC-07, AC-08
- SAD: [[../sad.md]] §4, §6
- Related ADR: [[0002-remember-the-switch-time-beside-the-current-session-pointer]]
