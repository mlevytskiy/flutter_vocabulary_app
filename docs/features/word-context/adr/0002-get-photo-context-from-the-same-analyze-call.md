---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "M"
ticket: "word-context"
---

# 0002 — Get photo context from the same analyze call

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

The `/analyze` route already supports `context=true` (the sentence the word appears in), off in the app today. The owner wants the full text and, on exercise sheets, an AI-written sentence (B7, B7b).

## Decision drivers

- AC-10
- NFR-01

## Considered options

1. Same call: `context=true`, plus `full_text` and per-word `context_source` (chosen)
2. A second request per photo

## Decision outcome

Chosen: Option 1. The prompt asks for `full_text` (the photo's running text, empty when none) and per word `context` + `context_source`: `photo` when quoted from the photo, `ai` when written because the photo has no real sentence. The validator accepts answers without the new fields (older deploys).

## Consequences

- + no extra request
- − a longer answer (more output tokens)
