---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0003 — Move each exercise's question building into a page source shared with its screen

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

The session needs single pages from eleven exercises whose question building lives inside each notifier's `build` (keyed by group) and whose question UI lives inside each screen. CLAUDE.md: move code, do not rewrite it.

## Decision drivers

- rule 3: move code, do not rewrite it; old screens keep working ("Try it")
- AC-08, AC-10: pages of every exercise in one frame
- learn-kit's cached data service stays the only AI data path

## Considered options

1. Per exercise: move the build body into `<exercise>_pages.dart` and the per-question UI into `<exercise>_page_body.dart`; both the old notifier/screen and the session call them (chosen)
2. Open each exercise's whole screen inside the session
3. Keep each old notifier and drive it one question at a time from the session through its existing methods

## Decision outcome

Chosen: option 1. Each exercise gets `Future<List<ExercisePage>> <exercise>Pages(PageInput input)` (words, others, dialogues, api, random) — the cut-and-pasted body of its notifier's `build` minus round splitting — and a `<Exercise>PageBody` widget cut from its screen. The old notifier calls the page source then splits rounds as before; the old screen renders the body widget. Matching boards produce one page per 4 words.

## Consequences

- + one question rule per exercise, used twice
- + old screens' tests guard the move
- − eleven moves; each is its own task
- − page bodies must accept an `onAnswered` callback instead of calling their notifier directly
