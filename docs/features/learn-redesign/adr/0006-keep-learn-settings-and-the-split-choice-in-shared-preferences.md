---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0006 — Keep learn settings and the split choice in shared preferences

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

Learn settings (preset, 11 switches, words per session) are app-wide; the split checkbox is remembered per collection (owner assumption 2).

## Decision drivers

- existing pattern: preference notifiers in providers.dart
- no new domain model needed for preferences

## Considered options

1. SharedPreferences notifiers (chosen)
2. Fields on `WordCollection` for the split choice

## Decision outcome

Chosen: option 1. `LearnSettingsNotifier` stores `learn.preset`, `learn.enabled` (list of ids) and `learn.wordsPerSession`; `LearnSplitNotifier(collectionId)` stores `learn.split.<collectionId>` (default true). New-user trial already moves every preference.

## Consequences

- + no schema change for preferences
- − a split choice for a deleted collection lingers as a tiny unused key
