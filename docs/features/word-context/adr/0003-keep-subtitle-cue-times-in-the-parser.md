---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "M"
ticket: "word-context"
---

# 0003 — Keep subtitle cue times in the parser

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

`SubtitleParser.parse` drops cue timings; the owner wants the time of the word (B6).

## Decision drivers

- AC-08

## Considered options

1. `parseTimed` returns `(start, text)` lines; `parse` maps it to text (chosen)
2. Re-parse the file at import end

## Decision outcome

Chosen: Option 1. `parseTimed` keeps the cue start of each line (split lines share it); `parse` stays as `parseTimed(...).map(text)` so the Worker request is unchanged. `firstLineTime(word, lines)` uses the exercises' whole-word match.

## Consequences

- + one parse
- − the import flow keeps the timed lines in memory until rows are built
