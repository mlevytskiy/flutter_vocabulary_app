---
status: Accepted
owner: "Maksym"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-29"
feature_size: "XS"
ticket: "spec AC-09"
---

# 0002 — Remember the switch time beside the current-session pointer

- **Status:** Accepted
- **Date:** 2026-09-29
- **Deciders:** Maksym (owner decision, 2026-09-29)

## Context

History is sorted by a session's `lastLocalModifiedAt` and shows its `updatedAt`. The launch rule reopens the pointed-to session only if its `lastLocalModifiedAt` is within 5 minutes; otherwise it starts a new empty session and offers RESTORE. That same 5-minute rule is the **only** way a new session starts — the app has no "New list" action. A switch to a week-old session must survive a relaunch without faking an edit, because the owner wants History ordered by real edits.

## Decision drivers

- Owner: History order = real edit time; a pick without an edit must not reorder it.
- Owner / spec AC-09: after picking a session, a relaunch lands back in it.
- CLAUDE.md rule 5: no new stored models; prefer no schema change.
- Keep the 5-minute rule, since it is how new sessions start.

## Considered options

1. **Store the pick (session id + time) beside the pointer** — `shared_preferences` next to `current_session_id`; the launch rule counts the later of the last edit and the pick, for the picked session only.
2. **Store "last opened" on every session** — a new Isar field on `Session`, same launch behaviour.
3. **Always reopen the pointed-to session, however old** — drop the 5-minute rule; needs a new "New list" action, since new sessions would otherwise never start.
4. **Re-stamp the edit times on switch** — simplest, but moves the session to the top of History without an edit.

## Decision outcome

**Chosen:** Option 1. It gives option 2's behaviour without a schema change or `build_runner` regeneration, and only one value is ever needed because only one session is current. Option 3 is a second feature (a "New list" action and a change to task-03's launch rule); option 4 breaks History order, which the owner rejected after first choosing it.

Rules:
- `switchTo` writes the pointer and the pick record `(sessionId, at = now)`.
- The pick record is never cleared; it counts only when its `sessionId` equals the session the launch rule is about to open (`prev.sessionId`), so a leftover record — after RESTORE, a new session, or a dangling pointer falling back to the newest session — is simply ignored.
- Launch rule case 3 is warm if `now − max(lastLocalModifiedAt, pickedAt) < 5 min`, with `pickedAt` taken only on an id match. Case 3's own re-save of the pointer leaves the record alone, so two relaunches within 5 minutes of a pick both reopen it.

## Consequences

**Positive**
- History order and the times it shows stay truthful: only real edits move a session.
- No Isar schema change; one extra preferences key.

**Negative**
- The launch rule reads two time sources, which adds one more case to test.
- RESTORE still re-stamps `lastLocalModifiedAt` (task-03), so restore and switch behave differently in History (SAD §11 accepted debt).

**Neutral**
- If "reopen however old" (option 3) is wanted later, it becomes a separate feature with a "New list" action; the pick record would still be useful there.

## Links

- Spec: [[../spec.md]] AC-09
- SAD: [[../sad.md]] §4, §6 flow 2, §8, §11
- Related ADR: [[0001-make-a-history-session-current-by-swapping-the-notifiers-session]]
