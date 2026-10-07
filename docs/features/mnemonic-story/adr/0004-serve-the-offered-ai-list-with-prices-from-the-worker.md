---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — mnemonic story (after learn-part-step-1)"
---

# 0004 — Serve the offered AI list with prices from the Worker

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk (accepted with the assumptions ledger, items A3, A4, A9, A10)

## Context

Words settings show three choices from a fixed list kept on the server, each with a price (AC-12). An AI that leaves the list must fall back to the default, and no run may start with it (AC-13). The server must refuse any AI that is not on its list, so that a caller cannot pick an unlisted, more expensive one (spec §6.1). The owner compares AIs by price and time, and the month's run prices must be within ±25 % of the invoices (spec §6 "Price accuracy"). learn-part-step-1 ADR-0003 kept the exercise list as JSON in the Worker with a Dart copy in the app, pinned by a test.

## Decision drivers

- The server's list is the only authority (spec §6.1, AC-13).
- Changing the list or a price should not need an app release (AC-13: "taken off the app's offered list").
- Price accuracy ±25 % against the invoices (spec §6).

## Considered options

1. **JSON in the Worker, fetched by the app** — `src/story/models.json` with id, name, provider, role, list prices, the 15-word estimate and the defaults. Served on an app-secret route, cached in the app, and enforced on every run and step.
2. **JSON in the Worker plus a Dart copy pinned by a test** (the learn-part-step-1 ADR-0003 pattern) — the app needs no fetch, but every list or price change needs an app release.

## Decision outcome

**Chosen:** Option 1. The list and its prices change more often than the app ships, and AC-13 expects the app to notice. The app caches the last list it fetched, so Words settings open offline with the last known list. The Worker prices each step from the provider's reported token use × the list price, or from the price per picture, and returns the price with the step. The app never computes a price itself. Higgsfield's "≈" price per picture (the plan price ÷ credits per picture) and the defaults (Sonnet 5.5 for both text steps, Grok for the picture) are entries in the same JSON, which resolves spec §8.

## Consequences

**Positive**
- Taking a model off the list or changing a price is one Worker deploy.
- One pricing rule, on the server, keeps the run records consistent.

**Negative**
- Words settings need one fetch to be current. With no network and no cache, they show only the defaults.
- List prices drift from the providers' real prices. The owner updates `models.json` and its `pricesAsOf` date together, as `subtitle_import_options.dart` does.

**Neutral**
- The app's Dart model of an offered AI follows the JSON shape. The `api` stage pins it in the contract.

## Links

- Spec: [[../spec.md]] AC-12, AC-13, §6, §6.1, §8
- SAD: [[../sad.md]] §4, §8
- Related ADR: [[0002-run-each-story-run-as-a-cloudflare-workflow]]
