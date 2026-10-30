---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
ticket: "learn-welcome"
---

# 0001 — Run the Learn flow in one notifier over one pager

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

The flow has four phases (warm-up, cards with story slots, main dialog, results) whose state depends on each other: the topic and mode feed the dialog, the ratings feed the dialog words and the results, the stories slot between cards.

## Decision drivers

- AC-01, AC-09, AC-10, AC-16
- rule 2: screen data in a `@riverpod` notifier
- reuse the Talk screen and the story tracker

## Considered options

1. One `LearnFlowNotifier` (state machine) and one `PageView` for cards and story pages (chosen)
2. A route per phase with state passed in route ids
3. Extend `LearningSessionNotifier`

## Decision outcome

Chosen: Option 1. `LearnFlowNotifier` keyed by collection id holds the phase, the warm-up answers, the card words, the groups, the story states and the dialog results; the flow screen shows the warm-up (Talk widgets), then one `PageView` of cards, story pages and wait pages, then pushes the Talk route in learn-flow mode and the results route.

## Consequences

- + one place to test the flow's rules
- + the session notifier stays as it is for exercises
- − the notifier must hand the dialog setup to the Talk notifier by id (route params + a provider)
