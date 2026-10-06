---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "M"
ticket: "import-from-quizlet"
---

# 0001 — Change the app, the Worker and the shared page as three surfaces

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The import itself happens only in the app (spec §1: read on the phone, no server step), but a kept word remembers its set, and the set must appear on the shared page in the source pager next to the photos (US-04, AC-13, AC-14) and be hidden by "Include sources" (US-05, AC-12). That needs the publish contract and storage in the Worker and new rendering on the shared page. good-looking-web (ADR-0001) and definition-mode (ADR-0001) split the same three parts the same way.

## Decision drivers

- Spec §2 goals 1–3: the import (app), set sources on the shared page (page), one switch for all sources (app + Worker + page).
- sad §1 quality goal 3: set sources are published or hidden by one switch — a contract that spans all three.
- Downstream stages gate their output by `target_surfaces` (screens, UI test tiers, Worker contract tests).

## Considered options

1. **Three surfaces: `mobile-app`, `backend-service`, `web-frontend`** — the app imports and publishes; the Worker accepts, stores and validates set sources; the shared page renders them.
2. **Two surfaces: `mobile-app`, `backend-service`** — treat the shared page as part of the Worker because the Worker renders it.

## Decision outcome

**Chosen:** Option 1. The set-source page of the pager and of the phone sources dialog is a visible interface change (AC-13, AC-14) that deserves the `screens` stage and the UI test tiers; filing it under the Worker would hide it from both. UI architecture is unchanged on both UI surfaces: the app stays Flutter (cross-platform), and the shared page stays server-rendered HTML enhanced by one plain-JavaScript file (good-looking-web ADR-0002).

## Consequences

**Positive**
- Every visible change (red + menu, link dialog, progress dialog with preview, results dialog lines, share-sheet switch, pager page) gets a screen state and a test tier.
- Consistent with the two previous cross-cutting features, so tasks and tests follow known layouts.

**Negative**
- More artifacts downstream (`screens` covers both the app and the page).
- A release needs both a Worker deploy and an app build, in that order (sad §7).

**Neutral**
- The Worker never contacts Quizlet (sad §3); its part is storage, a format check and rendering.

## Links

- Spec: [[../spec.md]] US-01, US-04, US-05
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0006-publish-set-sources-in-the-sources-list-with-a-kind]]
