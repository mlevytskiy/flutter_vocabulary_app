---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — mnemonic story (after learn-part-step-1)"
---

# 0005 — Let the app own the grouping rules and the AI only split words

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk (accepted with the assumptions ledger, item A2)

## Context

Grouping has many rules:
- 7 to 19 words per group only above 19 words to learn, and "All words" at or below that (AC-01, AC-02).
- Added words beside a story group in a small session become their own group (AC-02b).
- Grouping runs only when the words to learn changed (AC-03).
- An invalid answer is rejected (AC-04).
- Groups without a story keep their words, name and selection. Fewer than 7 leftover words wait, and a group whose run is in progress counts as a group with a story (AC-05).

All the state these rules need (the groups, their stories, runs in progress) lives on the phone (ADR-0003). Only the topical split needs an AI, and the spec fixes that AI on the server and does not count it against the allowance.

## Decision drivers

- Groups never change under a story or a run in progress (CONTEXT invariants; AC-05).
- Grouping time ≤ 30 s for a 60-word session (spec §6 "Grouping time").
- The rules must be testable without an AI call.

## Considered options

1. **App owns the rules, AI only splits** — the app decides which words to regroup and which groups may take more. It sends only those to the Worker, which asks a fixed AI and returns the split. The app validates the split and applies it.
2. **Worker owns the rules** — the app sends every word plus every group's state, and the Worker applies the rules and returns the final groups.

## Decision outcome

**Chosen:** Option 1. The phone already holds the state, and the rules are pure functions over it, so they live in one Dart file with unit tests. The Worker route stays thin: it checks the request shape, calls Haiku 4.5 with a grouping prompt, parses the JSON and returns it. Small sessions (≤ 19 words, AC-02 and AC-02b) never call the Worker. The app rejects an answer that leaves a word out, puts one in two groups or breaks 7 to 19 above 19, and shows "Could not group your words" (AC-04).

## Consequences

**Positive**
- Every grouping invariant is a Dart unit test, and the AI cannot break a group with a story, because that group is never sent.
- The Worker keeps no grouping state.

**Negative**
- A caller with the app secret can use the grouping route for other text. That is bounded by the per-address rate limiter and the cheap fixed model (spec §6.1 abuse case "Grouping calls spammed").

**Neutral**
- Moving the rules to the Worker later would mean porting the Dart rules file and its tests.

## Links

- Spec: [[../spec.md]] AC-01 – AC-05, AC-11, §6, §6.1
- SAD: [[../sad.md]] §4, §6
- Related ADR: [[0003-keep-word-groups-in-the-session-and-story-runs-in-their-own-collection]]
