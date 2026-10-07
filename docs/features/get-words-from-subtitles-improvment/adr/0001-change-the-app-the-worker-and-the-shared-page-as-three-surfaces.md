---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — get words from subtitles improvement (dialogues)"
---

# 0001 — Change the app, the Worker and the shared page as three surfaces

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

Film dialogues are picked by the AI inside the subtitle import (Worker), kept and learned in the app, and shown to the partner on the shared page (spec §1, AC-20). Scene pictures are drawn by paid AI behind the app secret and the story allowance (AC-19, AC-22). The surfaces chosen here decide which contracts, task layers and test tiers the later stages produce.

## Decision drivers

- AC-20 and AC-21 change what the shared page shows. Unlike mnemonic-story, the web is not left untouched here.
- Provider keys, the prompt and the allowance stay on the server (spec §6.1; sad §1 quality goal 3).
- Precedent: good-looking-web and learn-part-step-1 declared the same three surfaces when the page changed.

## Considered options

1. **App + Worker + shared page (`[mobile-app, backend-service, web-frontend]`)** — each changes: the app gets the setting, the pager, dialogue groups and the dialogue screen; the Worker gets dialogue picking, scene runs and dialogue storage; the page gets dialogue pages.
2. **App + Worker (`[mobile-app, backend-service]`)**, treating the page changes as Worker-rendered HTML inside the backend surface — the page is served by the same Worker script.

## Decision outcome

**Chosen:** Option 1. The page has its own client script, layouts and visible behaviour (dialogue pages in both layouts, live updates from the change feed). Declaring it a surface makes `screens`, `plan-tests` and `tasks` produce its UI tasks and its e2e-through-UI checks instead of leaving them implicit in Worker tasks.

## Consequences

**Positive**
- Each surface gets its own tasks and test tiers, including the page's dialogue rendering in both layouts.
- Spending stays behind the app secret and the allowance; the page only reads.

**Negative**
- Three surfaces make the feature larger, and a change touches three test suites.

**Neutral**
- The web learn page only gains the twelfth exercise in its list, which leads to coming soon (AC-22).

## Links

- Spec: [[../spec.md]] §1, AC-20 – AC-22
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0005-add-an-imports-rows-and-dialogues-to-the-published-session-automatically]]
