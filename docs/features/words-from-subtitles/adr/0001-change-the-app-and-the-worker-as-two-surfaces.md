---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-30"
feature_size: "S"
ticket: "docs/features/words-from-subtitles/spec.md"
---

# 0001 — Change the app and the Worker as two surfaces

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

A subtitle import starts on the phone (speed dial, import dialog, file, Settings, the current session) and needs a paid AI model to pick words (spec §1). The Anthropic key cannot ship inside the app, and the spec requires that only the learner's app can start an import and that the partner's shared page offers none (AC-13). Subtitle words must then behave like any other words on the shared page and in the export (AC-17).

## Decision drivers

- spec §6.1: the AI route accepts only the learner's app, with a per-address allowance; the app secret already ships in the app, the Anthropic key must not.
- AC-17: subtitle words look like typed words everywhere — no new field on the word row, so the shared page and the export need no change.
- ux-flows.md: posture mobile-only; every screen (SCR-01 … SCR-07) lives in the app.

## Considered options

1. **Two surfaces — mobile-app and backend-service** — the app gains the dialogs, parser and preferences; the Worker gains one secret-gated route with its allowance and model allow-list; the shared page is untouched.
2. **Three surfaces, adding web-frontend** — also mark imported rows on the shared page (for example a film label), as definition-mode and good-looking-web did for their own changes.

## Decision outcome

**Chosen:** option 1. `target_surfaces: [mobile-app, backend-service]`. Nothing about a subtitle word differs once it is in the session (AC-17, spec §3 "Keeping the subtitle sentence or film name on the word row" is a non-goal), so the page has nothing new to show; the only cross-surface contract is the new app→Worker route.

## Consequences

**Positive**
- The shared page, publish payload, D1 session tables and Anki export stay exactly as they are.
- `api` has one new contract; `tasks` gets `ui` and Worker layers only.

**Negative**
- Two deployables change together: the Worker (route plus migration) must be deployed before an app build that calls it.

**Neutral**
- A later "film name on the row" feature would add web-frontend then, with its own Isar and publish changes.

## Links

- Spec: [[../spec.md]]
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0002-strip-subtitles-in-the-app-and-send-dialogue-lines]]
