---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/tasks/active/task-19-definition-mode-setting.md"
---

# 0001 — Change the app, the Worker API and the shared page as three surfaces

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Definitions must be chosen and filled on the phone, validated and stored by the Worker, and shown on the partner's shared page and in its AnkiDroid download (spec US-07, US-08, AC-16, AC-17, AC-20). The shared page is HTML rendered by the Worker today.

## Decision drivers

- Spec §2 goal 3: definitions travel everywhere words travel.
- Quality goal 1 (sad §1): pre-feature sessions and links keep working — a contract between app, Worker and page.
- Owner's choice to treat the shared page as its own surface so it gets its own UI tasks and tests.

## Considered options

1. **mobile-app + backend-service** — the page counted as the Worker's server-rendered output.
2. **mobile-app + backend-service + web-frontend** — the page declared as its own surface.

## Decision outcome

**Chosen:** option 2. The page is where the partner experiences the feature (US-08); declaring it a surface gives it its own `ui` tasks and component / visual tests downstream, instead of hiding page work inside backend tasks.

## Consequences

**Positive**
- Page rendering (columns per mode, escaping, old-document fallback) gets explicit tasks and tests.
- Every downstream stage reads one declared list instead of guessing.

**Negative**
- More tasks and test rows than a two-surface declaration; the page is still one server-rendered template, not a separate app.

**Neutral**
- UI architecture per surface is fixed by the repo: the app stays Flutter (cross-platform), the page stays server-rendered by the Worker — no new UI stack (sad §4).

## Links

- Spec: [[../spec.md]] US-07, US-08
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0004-record-the-detail-mode-in-the-published-session]]
