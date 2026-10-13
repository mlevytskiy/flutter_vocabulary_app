---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — mnemonic story (after learn-part-step-1)"
---

# 0001 — Change the app and the Worker as two surfaces

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

Mnemonic story is used only in the app (spec §1, §3). The AI chain needs provider keys, which must not ship in the app, and a spending cap that a leaked app secret cannot bypass (spec §6.1). The web learn page stays as it is: Mnemonic story there still leads to the coming-soon page (AC-18). The surfaces chosen here decide which contracts, task layers and test tiers the later stages produce.

## Decision drivers

- Spending stays bounded, and nothing reachable from a shared link can start a run (sad §1 quality goal 1; spec AC-18, AC-19, §6.1).
- Provider keys and the offered model list stay on the server (spec §6.1, AC-12, AC-13).
- The precedent splits app and Worker the same way: photo extraction and subtitle import (`/analyze`, `/subtitles/words`).

## Considered options

1. **App + Worker (`[mobile-app, backend-service]`)** — the app gets the screens and the storage; the Worker gets the app-secret routes, the allowance and the AI chain. The web is untouched.
2. **App + Worker + web (`[mobile-app, backend-service, web-frontend]`)** — the same, plus declaring the web learn page a surface because AC-18 describes its behaviour.

## Decision outcome

**Chosen:** Option 1. Nothing changes on the web, so declaring it would only make the later stages produce empty UI tasks and web test tiers. AC-18 is kept on the Worker side: every story route is app-secret only (`public: false`), and a Worker test checks that the web learn page and its coming-soon link are unchanged and that no public route starts a run.

## Consequences

**Positive**
- Provider keys, the model list and the allowance live in one place the app cannot bypass.
- The later stages produce exactly the app UI tasks and the Worker contract.

**Negative**
- Two deployables must agree on one contract (the `api` stage writes it). An older app keeps working only while the Worker keeps the routes it calls.

**Neutral**
- Showing stories on the web later is a new roadmap step that adds `web-frontend` then (spec §3).

## Links

- Spec: [[../spec.md]] §1, §3, AC-18, §6.1
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0002-run-each-story-run-as-a-cloudflare-workflow]]
