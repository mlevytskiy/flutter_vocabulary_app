---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)", "Security Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #24 — collections-screen"
---

# 0001 — Change the app, the Worker and the shared page as three surfaces

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Maksym (owner) with Claude during the design pass

## Context

Almost all of collections-screen is in the app: names, folders, the recycle bin, the launch rule and the rename. The spec also needs the name on the shared page (AC-29–AC-31) and "collection" instead of "session" in the page's text (AC-33). The page is served by the Worker from D1, and today it has no title field.

## Decision drivers

- Spec AC-29: the shared page shows the collection's name, updated only by a new Share link.
- Spec AC-30 and §6.1: the partner sees the name and nothing else of the learner's filing.
- §2 constraint: no new packages and no new infrastructure; the Worker and page already exist.

## Considered options

1. **Three surfaces: mobile-app, backend-service, web-frontend** — the app files and publishes, the Worker stores the title, the page shows it.
2. **Two surfaces: mobile-app and backend-service** — treat the page's heading change as part of the Worker, since the Worker renders it.

## Decision outcome

**Chosen:** option 1. The page is a separate UI surface with its own layouts and tests (good-looking-web ADR-0001), and its heading and wording change is visible to the partner, so `screens`, `plan-tests` and `review` must see it as a surface. The title's storage is ADR-0008.

## Consequences

**Positive**
- Every downstream stage (`api`, `sequences`, `tasks`, `plan-tests`) knows that the Worker and the page are in scope.
- UI architecture does not change on either UI surface: Flutter in the app, server-rendered HTML with one plain-JavaScript file on the page.

**Negative**
- One more D1 migration and Worker deploy to coordinate with the app release.

**Neutral**
- The Worker's routes and JSON names keep saying `session` (spec §1, decision 1).

## Links

- Spec: [[../spec.md]] US-12, AC-29–AC-31, AC-33
- SAD: [[../sad.md]] §4
- Related ADR: [[0008-send-the-collection-name-as-the-shared-pages-title-in-a-nullable-column]]
