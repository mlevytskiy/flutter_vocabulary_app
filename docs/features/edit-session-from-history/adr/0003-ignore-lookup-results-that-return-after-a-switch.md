---
status: Accepted
owner: "Maksym"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-29"
feature_size: "XS"
ticket: "spec AC-07b"
---

# 0003 — Ignore lookup results that return after a switch

- **Status:** Accepted
- **Date:** 2026-09-29
- **Deciders:** Claude (easy-depth assumption, open to the owner's veto)

## Context

The main screen stays mounted under History. A translation, definition or photo lookup started there writes its result by row index after an `await`. If the learner switches before it returns, the write would land in a row of the newly picked session. RESTORE has the same latent gap today.

## Decision drivers

- Spec §2 / AC-07b: switching never loses or corrupts a word.
- Spec §6: switch ≤ 1 s — the switch must not wait on the network.

## Considered options

1. **Ignore late results** — capture the session id before the `await`; write only if it is still current.
2. **Write late results into the session that was left** — excluded by spec AC-07b (the left session keeps what it had at the moment of the switch); recorded because a reader will ask.
3. **Block the switch while a lookup runs** — show "wait" until everything returns.

## Decision outcome

**Chosen:** Option 1. One guard per result path, no cross-session writes, and the switch never waits (option 3 can stall 10+ s on a photo). The cost — a pending result is lost — is recoverable by tapping the lightning icon again.

## Consequences

**Positive**
- The picked session is never touched by an old request; closes the same gap for RESTORE.

**Negative**
- A lookup finishing just after the switch is discarded; its loading indicator simply disappears with the rebuild.

**Neutral**
- Every future async path on the main screen must apply the same guard (SAD §8).

## Links

- Spec: [[../spec.md]] AC-07b
- SAD: [[../sad.md]] §4, §8, §11
