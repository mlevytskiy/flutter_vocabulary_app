---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0007 — Serve talk turns from a Worker route with a daily talk counter

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

Talk needs an AI reply per learner turn, reachable only by the app (AC-23), with ≤ 20 talks a day app-wide and never refusing a reply inside a started talk (AC-24).

## Decision drivers

- AC-23, AC-24; §6 talk cost row
- existing: app secret header, D1 day counters, cheap model `GROUPING_MODEL`

## Considered options

1. New route on the existing Worker with a D1 talk counter (chosen)
2. Call the AI from the app directly
3. Reuse the sentence-check route

## Decision outcome

Chosen: option 1. New route in `learn/routes.ts` handled by `learn/talk.ts`: body `{kind: start|reply, scene, words[{word, translation}], target, history[{role, text}] ≤ 24}`. `start` takes a unit from `all_learn_talks` (20/day, migration 0008) and returns the opening; `reply` takes none and is capped by history length ≤ 24. The prompt asks for short replies that steer toward `target` without saying it, and returns the next suggested target.

## Consequences

- + same auth and counter pattern as learn-kit
- − a client could send replies without a start; acceptable: app-only secret and history cap bound it
- − needs a D1 migration before deploy
