---
id: T2
title: "Add the offered AI list with prices and the step pricing rule to the Worker"
layer: "domain"
deps: []
acs: ["AC-12", "AC-13"]
files_hint: ["vocab-photo-api/src/story/models.json", "vocab-photo-api/src/story/models.ts", "vocab-photo-api/test/story-models.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T2 — Add the offered AI list with prices and the step pricing rule to the Worker

## Why

[ADR-0004](../adr/0004-serve-the-offered-ai-list-with-prices-from-the-worker.md); [sad §4](../sad.md) choice 4 and "Spec §8 open questions, resolved".

## What

- `models.json`: `pricesAsOf`, then one entry per offered AI: `id`, `name`, `provider` (`anthropic` / `opencode-zen` / `xai` / `higgsfield`), `role` (`text` / `picture`), list prices (`inputUsdPerMTok`/`outputUsdPerMTok` or `usdPerPicture`, Higgsfield's marked `approx: true`), `estimate15Usd` for text AIs, and `defaults` {story: `claude-sonnet-5-5`, prompt: `claude-sonnet-5-5`, picture: <the Grok picture model>}. It also fixes the grouping model `claude-haiku-4-5-20251001`.
- Start with Sonnet 5.5 and Opus 5.5 at the prices in `subtitle_import_options.dart`. Add the OpenCode Zen, Grok and Higgsfield entries the owner confirms, and leave out any provider without a key yet (sad §2).
- `models.ts`: typed view, `isOffered(role, id)`, `priceOf(usage)` (tokens × list price, or the price per picture) and `estimateOnTimeout(model, inputTokens, outputLimit)` → `{usd, estimated: true}`.

## Definition of Done

**Done when:** `models.ts` exposes the typed list, `isOffered` and both pricing functions, and `story-models.test.mjs` covers role checks, the defaults being offered, token pricing, per-picture pricing and the timeout estimate.

- [ ] every default names an offered model of the right role
- [ ] an unlisted id, or a text id asked for as a picture, is not offered
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- The owner fills in the real Grok and Higgsfield ids and prices. Spec §8 is resolved in sad §4.
