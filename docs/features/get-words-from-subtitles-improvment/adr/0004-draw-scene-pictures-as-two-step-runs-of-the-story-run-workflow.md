---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — get words from subtitles improvement (dialogues)"
---

# 0004 — Draw scene pictures as two-step runs of the story run workflow

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

A scene picture is a story run of two steps, the picture prompt writer and then the picture maker, with no story step (spec §1). It takes one unit of the shared story allowance when its picture prompt step starts. It has "Try again" (prompt step, free) and "Draw again" (one unit), and it is listed in Story runs with its AIs, price and time (AC-14, AC-18, AC-19). Today `StoryRunWorkflow` always runs story → word check → prompt → picture, and D1 `story_runs.story_model` is `NOT NULL`.

## Decision drivers

- Spending stays bounded and a finished step is never paid again (sad §1 quality goal 3; spec §6 "Story allowance shared").
- Picture prompt writer ≤ 90 s, picture maker ≤ 120 s, as in mnemonic-story (spec §6).
- Dialogue text must reach the picture prompt writer as scene content only (spec §6.1).

## Considered options

1. **Same workflow, new run kind** — `kind: scene` skips the story writer and the word check. A scene prompt asks for one scene of invented characters, and code puts the dialogue's lines into speech bubbles verbatim. Migration `0005` adds `kind` and `scene_text`.
2. **A separate `ScenePictureWorkflow`** with its own records, routes and app tracking.

## Decision outcome

**Chosen:** Option 1. The allowance, the durable no-retry steps, the timeouts, the status, redo and picture routes, the R2 clean-up, the app's tracker and the story runs screens are all reused. The only branch is on `kind`. A separate workflow would duplicate all of these, and the two paths could drift apart, for example on timeouts or "≈" prices.

## Consequences

**Positive**
- One allowance table and one tracker cover stories and scene pictures (spec §6 "Story allowance shared").
- Scene runs appear in Story runs and run details with no new screen.

**Negative**
- The workflow and the run screens branch on `kind`.
- `story_model` holds an empty string for a scene run, because SQLite cannot drop `NOT NULL` without rebuilding the table.

**Neutral**
- The picture prompt step stores the assembled image prompt, as for stories, so "Draw again" redraws from the same prompt (AC-18).

## Links

- Spec: [[../spec.md]] §1, AC-14, AC-18, AC-19, §6.1
- SAD: [[../sad.md]] §4, §6
- Related ADR: mnemonic-story ADR-0002; [[0003-keep-film-dialogues-in-the-session-and-link-their-words-by-row-id]]
