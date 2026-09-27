---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0001 — Change the app, the Worker API and the shared page as three surfaces

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The feature needs work in three separately running places: the learner's app must keep source photos, link rows to them and publish them behind an "include photos" switch (US-11, US-12); the Worker must store editable sessions, accept edits, meter autofill and serve photos (US-05 – US-10, US-13); and the shared page stops being a printout and becomes an editing client with two layouts, a photo pager and a photo dialog (US-01 – US-10). definition-mode made the same three-way split (its ADR-0001).

## Decision drivers

- spec §2 goals 1–3 span all three places: reading on any device (page), correcting the list (page + Worker), photos linked to words (app + Worker + page).
- sad §1 quality goal 1 (edit integrity) is a page–Worker contract; quality goal 2 (bounded public write surface) is enforced in the Worker; US-11/US-12 are app work on Isar models.
- ux-flows.md's screen inventory has app screens (SCR-01 – SCR-03) and page screens (SCR-04 – SCR-07).

## Considered options

1. **mobile-app + backend-service + web-frontend** — each place is a declared surface with its own tasks and test tiers.
2. **backend-service + web-frontend** — the app treated only as an API consumer, its photo keeping folded into backend tasks.

## Decision outcome

**Chosen:** option 1. The app half (photo keeping, row–photo links, the switch, background upload) is real Flutter and Isar work that needs its own `ui` tasks and tests; the page is the partner's whole experience and needs component and e2e-through-UI tests for editing, conflicts and Undo.

## Consequences

**Positive**
- Every downstream stage reads one declared list; the page's editing behaviour gets explicit UI tasks and browser tests.

**Negative**
- More tasks and test-plan rows than a two-surface declaration.

**Neutral**
- The app stays Flutter (cross-platform); its UI architecture is not revisited. The page's UI architecture is ADR-0002.

## Links

- Spec: [[../spec.md]] §2, US-01 – US-13
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0002-render-the-table-on-the-server-and-enhance-it-with-plain-javascript]]
