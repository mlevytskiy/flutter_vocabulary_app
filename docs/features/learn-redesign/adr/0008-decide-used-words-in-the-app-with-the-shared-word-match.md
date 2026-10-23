---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0008 — Decide used words in the app with the shared word match

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

AC-21: only the learner's own replies tick words, by the same whole-word rule as exercises; the AI must not be trusted to judge.

## Decision drivers

- AC-21
- learn-kit: the app, not the AI, decides whether a sentence uses the word

## Considered options

1. `matchPlaces` on the learner's text in the app (chosen)
2. A looser lemma match in the app (took/take, children/child) via a small irregular-forms table

## Decision outcome

Chosen: option 1. `talk_rules.dart` ticks a word when `matchPlaces(learnerText, word)` is non-empty; hints and scoring (used without hint = clean, after hint = miss, unused = unchanged) are pure functions.

## Consequences

- + free, deterministic, testable
- − irregular forms (took/take) are not matched, as in the exercises
