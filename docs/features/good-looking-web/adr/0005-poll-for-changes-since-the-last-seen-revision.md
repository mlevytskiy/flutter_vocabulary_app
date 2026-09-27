---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0005 — Poll for changes since the last seen revision

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Other partners' saved edits must appear on an open page within 10 s without reload (AC-12). D1 (ADR-0003) has no way to push changes to browsers, and live keystroke-level co-editing is a non-goal (spec §3).

## Decision drivers

- spec §6: others' saved edits on an open page ≤ 10 s, without reload.
- AC-35: two partners working 15 minutes at a normal pace are never turned away for going too fast.
- Workers free plan: 100,000 requests per day.
- ADR-0004: every change already carries a session revision.

## Considered options

1. **Polling** — every ~5 s the page asks "what changed since revision N?".
2. **WebSocket push through a Durable Object** — a per-session object holds open connections and forwards each saved change.

## Decision outcome

**Chosen:** option 1. The answer lists changed cells, new rows, tombstones of deleted rows and photo slots that have received their bytes since N (so a placeholder turns into its photo), plus the new revision. The page polls about every 5 s, pauses while the tab is hidden and polls at once when it becomes visible again. A change that arrives for a cell the partner is typing in is held, not applied, and surfaces as the AC-11 choice when they save.

## Consequences

**Positive**
- No new infrastructure beside D1; survives flaky connections because every poll resumes from the last revision seen.
- Easy to test: the change feed is a plain read.

**Negative**
- About 12 requests per minute per open tab (three partners for an hour ≈ 2,000 requests) — well inside the free plan, but polling is excluded from the write rate limit so it cannot trip AC-35.
- Updates arrive within ~5 s, not instantly.

**Neutral**
- Switching to push later changes only the transport; the change-feed shape stays.

## Links

- Spec: [[../spec.md]] AC-12, AC-35, AC-37, §3, §6
- SAD: [[../sad.md]] §4, §6
- Related ADR: [[0004-detect-edit-conflicts-with-a-revision-per-cell]]
