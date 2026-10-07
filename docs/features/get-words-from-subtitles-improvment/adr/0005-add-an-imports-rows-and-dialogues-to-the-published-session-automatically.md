---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — get words from subtitles improvement (dialogues)"
---

# 0005 — Add an import's rows and dialogues to the published session automatically

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

Spec AC-20 says that dialogues added by a later import, and pictures drawn later, reach a session's existing shared link "the way word changes do, without sharing again". Today word changes on the phone reach the link only through Share → link, a republish that overwrites the same link and replaces the partner's edits (good-looking-web ADR-0008). The phone never reads the partner's edits. A dialogue on the page also needs its word rows to exist there, or nothing can be bold or listed.

## Decision drivers

- AC-20: new dialogues and pictures reach the existing link without the learner sharing again.
- The partner's edits must not be lost by this (good-looking-web: "0 lost edits").
- Spending and writes stay behind the app secret; the page can only read dialogues (AC-22).

## Considered options

1. **With the publish only** — dialogues and picture declarations go in the publish payload and reach the link on the next Share → link (republish), like word changes today.
2. **Automatic append** — after Done of an import into a published session, the app sends that import's new rows and dialogues to a new route (app secret + edit token, idempotent by import id); scene pictures are uploaded after collection; undelivered items are retried, also after restart. Publish and republish also carry the dialogues.

## Decision outcome

**Chosen:** Option 2. It meets AC-20 as written. Nothing on the page is overwritten, so the partner's edits stay. The rows a dialogue needs always arrive with it, because a dialogue's words are exactly rows that import added. The owner accepted the hidden cost: words typed by hand, and the learner's edits, still reach the link only by a republish. So for now an import's words reach the link on their own, and other changes do not.

## Consequences

**Positive**
- The partner sees new dialogues, their words and their pictures without the learner sharing again, and their own edits stay.
- Appending does not touch existing rows, so it cannot cause an edit conflict.

**Negative**
- A new delivery path in the app, with a retry that survives a restart (a pending mark on each `FilmDialogue`), and a new Worker route with D1 tables for dialogues and their words.
- Two sync rules for words: an import with dialogues appends its rows, while other changes need a republish.
- The feature grows towards size L (§11).

**Neutral**
- If the link has expired (30 days) or was never created, nothing is sent. A first publish carries all dialogues.
- The phone still never reads the partner's edits (AC-21, read as "the same rules in both places").

## Links

- Spec: [[../spec.md]] §1 (decision on AC-20), AC-20, AC-21, AC-22
- SAD: [[../sad.md]] §4, §5, §6, §11
- Related ADR: good-looking-web ADR-0005 (change feed), ADR-0006 (declare then upload), ADR-0008 (republish overwrites); [[0001-change-the-app-the-worker-and-the-shared-page-as-three-surfaces]]
