---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0008 — Overwrite the same link when a session is republished

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Every publish creates a new link today. A forwarded link can be vandalised (spec §6.1), and the owner prefers that publishing the same session again restores the list under the same link rather than producing a new one (spec OQ-4 default, clarify 2026-09-27). The Worker's publish route is gated only by the app's shared secret, which ships in every app build.

## Decision drivers

- spec §6.1 abuse case "forwarded link used to vandalise the list": republishing should restore it.
- spec OQ-4 default: republishing overwrites the same link; takedown stays out of scope; D4 (30 days, no delete) stands.
- sad §1 quality goal 2: nobody but the learner who published a session may overwrite it.

## Considered options

1. **Overwrite the same link** — the app remembers the published session and republishing replaces its rows and photos.
2. **Keep a new link per publish** — as today; the old link lives out its 30 days.

## Decision outcome

**Chosen:** option 1. The first publish returns, besides the link, a random edit token; the app stores the published id and the token on its `Session`. A republish sends both; the Worker (keeping only a hash of the token) replaces the session's rows and photo slots in D1, keeps its original expiry (D4) and raises the session revision, recording "replaced at revision R"; the revision never goes back, so the change feed answers any page whose cursor is below R with a reload marker and the page reloads the list (ADR-0005). If the link has expired or the token does not match, the Worker creates a new link instead. The share sheet warns before a republish that the page's edits will be replaced.

## Consequences

**Positive**
- A vandalised or outdated list is restored under the link the partner already has.
- The token stops anyone holding the app's shared secret from overwriting someone else's session.

**Negative**
- The partners' edits on that page are gone after a republish; the warning is the only protection.
- Two new fields on the app's `Session` (published id, edit token) and a new branch in the publish route.

**Neutral**
- Photos no longer declared after a republish stay in R2 until the lifecycle rule removes them; they are unreachable because the page lists only declared slots.

## Links

- Spec: [[../spec.md]] §6.1, §8 OQ-4, AC-23, AC-28
- SAD: [[../sad.md]] §4, §5, §11
- Related ADR: [[0006-declare-source-photos-in-the-publish-payload-and-upload-bytes-after]]
