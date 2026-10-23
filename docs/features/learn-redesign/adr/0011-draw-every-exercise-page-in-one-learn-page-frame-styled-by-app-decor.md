---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0011 — Draw every exercise page in one learn page frame styled by AppDecor

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

C1 asks for one frame for every page in every theme; five themes exist and new colours must be AppDecor slots.

## Decision drivers

- AC-10; §6 frame row
- CLAUDE.md: a new hard-coded colour goes to AppDecor as a slot

## Considered options

1. One `LearnPageFrame` taking a page body and verdict, with AppDecor slots (chosen)
2. A shared `LearnPageTheme` extension that each page body applies itself, without a common frame widget

## Decision outcome

Chosen: option 1. `LearnPageFrame(step, page, total, chip, body, verdict, onCheck, onContinue, onClose)`; verdict colours from new `AppDecor.learnRight/learnWrong` defined in every theme; card/radius/fonts from the theme. Old exercise screens keep their look (rule 3).

## Consequences

- + one place to tune the look
- − page bodies must fit a card (typed answers, boards)
