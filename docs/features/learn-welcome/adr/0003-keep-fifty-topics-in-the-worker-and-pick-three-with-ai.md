---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
ticket: "learn-welcome"
---

# 0003 — Keep fifty topics in the Worker and pick three with AI

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

Q1 of the warm-up offers 3 topics that fit the words (owner A3).

## Decision drivers

- AC-03
- NFR-01
- cost

## Considered options

1. 50 topics as a constant in the Worker; `POST /learn/topics` asks the mission's model for 3 ids (chosen)
2. Topics in the app, matched by keywords
3. AI invents topics

## Decision outcome

Chosen: Option 1. `topics.ts` exports 50 `{id, title, description, keywords}`; the route sends the card words and the list (ids + keywords) to the mission's model and returns 3 valid ids (invalid or missing ids filled from a keyword overlap score). Not counted toward the talk allowance. The app waits 4 s, then shows 3 bundled fallback topics.

## Consequences

- + the list changes without an app release
- + cheap prompt
- − one more Worker route to keep
