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
2. **App only, with the name in an existing published field** — e.g. as a fake first word row or inside a source name, so the Worker needs no change.

## Decision outcome

**Chosen:** option 1. The page must show the name as its title and nothing else may change shape for the partner; smuggling it through a word row or a source would show up as data on the page and in the partner's exports. A nullable column is the honest home (ADR-0008).

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
