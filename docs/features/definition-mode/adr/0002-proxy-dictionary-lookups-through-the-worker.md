---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/tasks/active/task-19-definition-mode-setting.md"
---

# 0002 — Proxy dictionary lookups through the Worker

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Typed words get definitions from the Merriam-Webster Collegiate API, which needs a key (free, non-commercial, 1,000 calls/day). `lib/config/vocab_api_config.dart` — where CLAUDE.md rule 4 says secrets go — is tracked by git despite being described as gitignored, so a key added there would be committed. This was open decision D10 (spec §8).

## Decision drivers

- Spec §6.1: a new third-party secret; abuse case "extracted key exhausts the allowance".
- Quality goal 2: graceful degradation and quota safety.
- Spec §6 NFR: lightning fill ≤ 1,000 ms p95 — an extra hop must fit.
- The Worker is being changed and deployed for this feature anyway (ADR-0001).

## Considered options

1. **App calls Merriam-Webster directly** — key as a constant in `vocab_api_config.dart`, after untracking that file.
2. **App calls a new Worker route; the Worker calls Merriam-Webster** — key stored as a Cloudflare Worker secret.

## Decision outcome

**Chosen:** option 2. The key never ships inside the APK, can be rotated without an app release, and the Worker becomes the single place to add caching or a daily cap later. The app authenticates with the `x-app-secret` header it already sends for photos and publishing. The extra hop is small next to the 1,000 ms budget.

## Consequences

**Positive**
- No dictionary key in the app or in git; rotation is `wrangler secret put`.
- One place to normalise the dictionary's response (headword filter, suggestions for unknown words) for the app.

**Negative**
- A new Worker route to build, verify and deploy; lookups fail if the Worker is down.
- One more network hop per lookup.

**Neutral**
- The Worker's own URL and app secret stay in `vocab_api_config.dart` as today; untracking that file is a separate clean-up, not required by this decision.

## Links

- Spec: [[../spec.md]] US-03, US-04, AC-05..AC-08, §6.1
- SAD: [[../sad.md]] §4, §8
- Related ADR: [[0003-store-definition-text-and-senses-on-the-word-row]]
