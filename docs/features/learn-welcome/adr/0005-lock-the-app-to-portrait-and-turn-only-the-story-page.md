---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
ticket: "learn-welcome"
---

# 0005 — Lock the app to portrait and turn only the story page

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

The story picture is 16:9 with captions inside; the owner wants it landscape and auto-rotation blocked elsewhere (A11, A12).

## Decision drivers

- AC-11

## Considered options

1. Portrait in Info.plist/manifest + `SystemChrome.setPreferredOrientations`; the story page sets landscape while shown (chosen)
2. Show the picture rotated 90° inside a portrait screen

## Decision outcome

Chosen: Option 1. iOS keeps landscape in Info.plist (needed to rotate at all) but the app sets portrait at start; Android declares no fixed orientation in the manifest and relies on `SystemChrome`. The story page sets landscape on show and portrait on leave; tablets the same.

## Consequences

- + real full-screen landscape
- − iOS 16+ needs `setPreferredOrientations` plus a geometry update; tested on device

## Amendment (learn-flow-cards, owner 2026-11-01)

The story page now stays portrait (the picture fitted to its card). Its zoom button opens `StoryZoomView`
(`lib/features/learn/flow/story_zoom.dart`), a full-screen dialog over the flow that sets landscape when it opens
and portrait as soon as it closes (cross or Back; again on dispose). The zoom is now the only place the app turns.
