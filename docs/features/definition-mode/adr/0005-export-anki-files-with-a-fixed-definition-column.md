---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/tasks/active/task-19-definition-mode-setting.md"
---

# 0005 — Export AnkiDroid files with a fixed definition column

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The AnkiDroid file is written in two places — the app (`lib/features/words_table/anki_export.dart`) and the Worker (`vocab-photo-api/src/session/anki.ts`) — with header `#tags column:3` (word, translation, tags). A definition placed in column 3 would be parsed as space-separated tags. Outputs follow the current mode (spec §1 decision), so column meaning must not change between exports.

## Decision drivers

- Spec AC-15, AC-20: word, translation and definition in fixed places; nothing becomes a tag; the page's file matches the app's.
- Failure-mode review: mode-dependent column meaning mixes decks and can overwrite studied translations on re-import.

## Considered options

1. **One back field** — translation, a line break, then the definition, in the existing 3-column shape.
2. **Separate definition column** — word, translation, definition, tags (`#tags column:4`); the column the mode hides is left empty.

## Decision outcome

**Chosen:** option 2 (owner's choice during specify). Column meaning is identical in every export, and the definition can be templated separately inside Anki. The format spec in `vocab-photo-api/README.md` is updated once and both writers follow it, each with a byte-level test (app) or typecheck plus curl check (Worker).

## Consequences

**Positive**
- Stable columns across modes; no junk tags.
- Definitions can be shown, hidden or given their own card type in Anki.

**Negative**
- The learner creates a matching 3-field note type in Anki once; importing into the old Basic type misplaces the definition.
- Two writers must change in lockstep.

**Neutral**
- Old exported files remain valid 3-column files.

## Links

- Spec: [[../spec.md]] US-07, US-08, AC-15, AC-20
- SAD: [[../sad.md]] §4, §8
- Related ADR: [[0004-record-the-detail-mode-in-the-published-session]]
