---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "S"
ticket: "learn-part-step-1"
---

# 0001 — Change the app, the Worker and the shared page as three surfaces

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The learn page exists in two places (spec §1). In the app it is opened from a session's Words screen. On the web it is opened from the shared page or from its own link (US-01, US-04). The web side needs new public routes on the Worker (`GET /s/:id/learn`, `GET /s/:id/learn/:exercise`), each with the dead-link answer of AC-09, plus a Learn button and new pages in the browser. good-looking-web (ADR-0001) and import-from-quizlet (ADR-0001) split the same three parts the same way.

## Decision drivers

- Spec §2 goals 1 and 2: the learn page is reachable from the app and from a shared link, and it shows the same plan in both places.
- sad §1 quality goal 1, one plan on two pages: the app's copy and the web's copy are separate surfaces that must be checked against each other.
- sad §1 quality goal 2: the app (≤ 300 ms) and the web (≤ 1.5 s on 4G) have separate open-time targets.
- Downstream stages gate their output by `target_surfaces`: the Worker route contract, the screen states and the UI test tiers.

## Considered options

1. **Three surfaces: `mobile-app`, `backend-service`, `web-frontend`.** The app shows Learn, the learn page and the coming-soon screen. The Worker serves the two new public read-only routes. The browser gets the Learn button and the web pages.
2. **Two surfaces: `mobile-app`, `web-frontend`.** The Worker's routes count only as the way the web pages are delivered, because they add no JSON, no write and no secret. That means no route contract.

## Decision outcome

**Chosen:** Option 1. The new routes have answers that matter to the spec: a live learn page, "No words to learn", and the 404 "gone" page that must not reveal whether a session existed (AC-08b, AC-09). Writing them down as a contract keeps them testable apart from how the pages look. It is also consistent with the two previous cross-surface features.

## Consequences

**Positive**
- Every visible change (the top bar's three layouts, the learn page, the coming-soon screen, the shared page's Learn) gets a screen state and a UI test tier.
- The Worker's new routes are pinned by a contract, including the dead-link answer.

**Negative**
- More stage output (api, screens) for an S feature than the two-surface option would need.

**Neutral**
- The two UI surfaces keep their existing architecture. The app stays Flutter, and the shared page stays server-rendered HTML with plain JavaScript. The web learn page's own shape is [ADR-0002](0002-render-the-web-learn-page-on-the-worker-and-keep-ticks-in-its-link.md).

## Links

- Spec: [[../spec.md]] US-01, US-04, AC-08, AC-08b, AC-09
- SAD: [[../sad.md]] §4
- Related ADR: [[0002-render-the-web-learn-page-on-the-worker-and-keep-ticks-in-its-link]], [[0003-keep-the-exercise-list-as-json-in-the-worker-and-test-the-app-copy-against-it]]
