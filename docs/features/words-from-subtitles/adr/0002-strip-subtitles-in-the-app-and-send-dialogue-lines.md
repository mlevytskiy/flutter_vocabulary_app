---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-30"
feature_size: "S"
ticket: "docs/features/words-from-subtitles/spec.md"
---

# 0002 — Strip subtitles in the app and send dialogue lines

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

An SRT or VTT file is cue numbers, timings, formatting tags (`<i>`, `{\an8}`), sound captions (`[door slams]`), speaker labels and the spoken lines. Something must turn it into the lines the AI reads, refuse a file that is not subtitles (AC-10), and keep captions and marks out of the proposed words and film sentences (AC-08). Where that happens fixes the shape of the new app→Worker request and how much the Worker can check about what it is sent (spec §6.1 abuse cases).

## Decision drivers

- AC-08, AC-10, AC-11: clean film sentences; a clear message for a file with no subtitles; a 1 MB file limit checked before Start.
- spec §6.1: the route must not work as a general-purpose AI for someone holding the leaked app secret.
- Keep the Worker request small and the parser testable.

## Considered options

1. **The app strips the file** — a pure-Dart parser produces dialogue lines; the Worker receives `lines[]` plus the options and checks only bounds (count, line length, body size).
2. **The Worker strips the file** — the app sends the raw file text; a TypeScript parser in the Worker checks the subtitle format (cue blocks with timings) and refuses anything else before the AI call.

## Decision outcome

**Chosen:** option 1 (owner's choice). The parser in `lib/core/services/subtitle_parser.dart` reads SRT and VTT, drops cue numbers, timings, tags, bracketed and parenthesised captions, `NAME:` labels and music marks, and returns the spoken lines; a file with no cue blocks is refused on the phone with the AC-10 message and no request. The request to `POST /subtitles/words` carries dialogue lines of at most 200 characters each (the parser splits longer ones) totalling at most 1 MB — so every file the app accepts (≤ 1 MB, AC-11) fits — plus level, purpose, maximum, model and the current session's words. Whether the lines are English is judged by the model, which returns a flag the Worker turns into the AC-10 response.

## Consequences

**Positive**
- A smaller request (dialogue only), and "not a subtitle file" is answered on the phone without a network call or an allowance unit.
- Parser edge cases are covered by fast Dart unit tests with fixture files.

**Negative**
- The Worker can no longer prove it was sent subtitles: anyone with the app secret can send any text split into short lines and get words picked from it. The spend is bounded by the allowance and the daily cap (ADR-0003) and the model allow-list (ADR-0004), not by the shape check. Tracked in SAD §11; spec §6.1 amended.
- A parser bug ships with an app release, not a Worker deploy.

**Neutral**
- Moving the parser to the Worker later changes only the request body and adds a Worker module; the response shape stays.

## Links

- Spec: [[../spec.md]] AC-08, AC-10, AC-11, §6.1
- SAD: [[../sad.md]] §4, §8, §11
- Related ADR: [[0003-count-subtitle-imports-per-address-and-per-day-in-d1]]
