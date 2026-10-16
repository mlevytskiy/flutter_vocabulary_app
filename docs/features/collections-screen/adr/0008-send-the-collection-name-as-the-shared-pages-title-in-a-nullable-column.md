---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)", "Security Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0008 — Send the collection name as the shared page's title in a nullable column

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

The shared page shows the collection's name as its title (AC-29). A rename reaches the page only when the learner shares as a link again; automatic dialogue and picture deliveries never change it; a page published before this feature keeps its old title until shared again. D1's `sessions` table (`migrations/0001_sessions.sql`) has no title, and the page heading is the fixed "Vocabulary" (`src/session/page.ts:259`).

## Decision drivers

- Spec AC-29, AC-30; §6.1: a learner-typed field on a public page, shown as plain text.
- ADR-0001: Worker routes and JSON names keep saying session.
- Old and new app and Worker versions must work together during the rollout (§7).

## Considered options

1. **A nullable `title` column** — migration `0007` adds `title TEXT NULL`; create and republish set it from an optional `title` in the body (1–60 characters, one line, else 400); dialogue and picture routes never touch it; the page shows `escapeHtml(title)` or "Vocabulary".
2. **A separate `session_meta` table keyed by session id** — the title (and any later page metadata) outside `sessions`.

## Decision outcome

**Chosen:** option 1. A one-to-one side table adds a join to every page render and a second row to delete on cleanup, for one short field. A nullable column keeps pages published before this feature on "Vocabulary" with no backfill, and an old Worker simply ignores the extra field.

## Consequences

**Positive**
- The page heading follows exactly what the learner last shared.
- No backfill; old links keep working unchanged.

**Negative**
- One more migration (`0007` + down) and the Worker's validation must match the app's name rule.

**Neutral**
- The page's `<title>` and `<h1>` both use the name; a test pins that markup in a name is shown as text.

## Links

- Spec: [[../spec.md]] US-12, AC-29–AC-31, §6.1
- SAD: [[../sad.md]] §4, §5, §8
- Related ADR: [[0001-change-the-app-the-worker-and-the-shared-page-as-three-surfaces]]
