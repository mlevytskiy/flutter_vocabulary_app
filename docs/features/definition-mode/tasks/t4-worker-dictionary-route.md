---
id: T4
title: "Add the Worker dictionary route with the 30-day cache"
layer: "ports"
deps: []
acs: ["AC-05", "AC-06", "AC-07", "AC-08"]
files_hint: ["vocab-photo-api/src/define.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/src/routing.ts", "vocab-photo-api/src/env.ts", "vocab-photo-api/wrangler.jsonc"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T4 — Add the Worker dictionary route with the 30-day cache

## Why

Derives from [ADR-0002](../adr/0002-proxy-dictionary-lookups-through-the-worker.md), [sad §6 flow 1, §7 cache, §8 outcomes and timeouts](../sad.md).

## What

New route module `define.ts`, behind the existing `x-app-secret` check: read `MW_API_KEY` from the Worker secret; look in `DEFINITIONS` KV (lowercased word) first; otherwise call the Collegiate API with a 4 s timeout, keep entries whose `meta.id` (before `:`) matches the word (fall back to all), collect `shortdef` senses. Return exactly one of: senses / not found with suggestions / temporarily unavailable. Cache only successful answers for 30 days. One log line per lookup with outcome (`cache hit` / `found` / `not found` / `unavailable`) and duration. Declare the `DEFINITIONS` KV binding and env types.

## Definition of Done

- [ ] `npm run typecheck` clean.
- [ ] Against `wrangler dev` with a real key: `tenacious` → senses (first = "persistent in maintaining…"-style short sense); `determinated` → not found with suggestions including "determined"; a bogus key → temporarily unavailable; second `tenacious` call logs `cache hit`.
- [ ] Missing or wrong app secret is rejected like the other routes.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Worker has no test runner — verification is typecheck + curl against `wrangler dev`, recorded in the task notes. Parsing mirrors `investigations/dictionary-apis/src/providers/merriam-webster.mjs`.

## Verification (2026-09-27, `wrangler dev`, real key in `.dev.vars`)

- RED: `POST /define` before the change → `404 {"error":"Not found"}`.
- `tenacious` → `senses` (3: "aggressively persistent in maintaining, adhering to, or seeking something valued or desired", "enduring especially when challenged", "retentive"), 134 ms.
- `determinated` → `not_found` with suggestions incl. "determined".
- `Tenacious` again → log `define cache hit "Tenacious" 0ms`.
- No `x-app-secret` → 401; non-JSON body → 400.
- Bogus key (`--var MW_API_KEY:bogus-key`) → 503 `unavailable` ("unexpected format": the dictionary answers an invalid key with a plain-text page).
- `npm run typecheck` clean. `wrangler.jsonc` carries a placeholder `DEFINITIONS` id — create the namespace and paste its id before deploying (T17).
