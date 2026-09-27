---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0007 — Call the translation endpoint from the partner's browser

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Translation lightnings on the shared page (US-08, US-09) need a source of translations. The app uses Google's undocumented `translate.googleapis.com/translate_a/single` endpoint from the phone. A server-side call to a free service may be blocked, as happened with Reverso (spec OQ-1). Whether the endpoint answers a browser on another origin (CORS) could not be confirmed during design: from the design machine it answered 429 (too many requests).

## Decision drivers

- spec §1 and AC-18: translation autofill costs no dictionary quota and is not metered.
- spec OQ-1 default (resolved at clarify 2026-09-27): call the free service from the partner's browser.
- sad §1 quality goal 2: the Worker's public surface stays bounded.

## Considered options

1. **From the partner's browser** — the page script calls the endpoint directly, parsing the answer the way the app does.
2. **Through the Worker** — the page asks the Worker, which calls the endpoint from Cloudflare's addresses, with its own limit and a cache.

## Decision outcome

**Chosen:** option 1, gated by a spike as the first task: a page served by `wrangler dev` must get a translation from the endpoint in Chrome and Safari. Translation autofill then runs outside the allowance and outside the Worker, and the page's content-security policy allows exactly that one origin. If the spike fails, this ADR is superseded by option 2.

## Consequences

**Positive**
- No server quota, no counter, no new Worker route for translation.

**Negative**
- An undocumented endpoint can change, throttle or refuse browsers without notice; the page then shows "nothing found" or an error for translation lightnings while definition autofill keeps working.

**Neutral**
- The fallback (option 2) adds one route and one counter in D1 and needs a new ADR.

## Links

- Spec: [[../spec.md]] US-08, US-09, AC-16, AC-17, AC-18, §8 OQ-1
- SAD: [[../sad.md]] §3, §4, §11
