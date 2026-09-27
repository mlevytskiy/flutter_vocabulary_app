---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/tasks/active/task-19-definition-mode-setting.md"
---

# 0003 — Store the definition text and its senses on the word row

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Each word row is an embedded `WordPair` inside an Isar `Session`. Translations store the chosen text plus the dots popup's alternatives as JSON (`translationOptionsJson`), so reopening the popup needs no new request. Definitions need the same two things (spec US-03, US-04, AC-13).

## Decision drivers

- Quality goal 2: every lookup spends the shared daily allowance; avoid repeat lookups.
- Quality goal 1: definitions survive a restart; older sessions open with empty definitions (AC-13).
- `isar_community` pinned to 3.3.0-dev.1: adding fields is a regenerate, not a migration.

## Considered options

1. **Definition text plus the fetched senses as JSON** (`definition`, `definitionOptionsJson`, and the `definitionMarkedFilled` flag that drives the lightning icon's filled state), mirroring translation.
2. **Definition text only**, senses kept in memory for the screen's lifetime.

## Decision outcome

**Chosen:** option 1. Reopening the senses list after a restart or a row rebuild costs no lookup, and the dots icon can show whether senses are loaded exactly as it does for translation. Both fields default to empty/null, so older sessions load unchanged.

## Consequences

**Positive**
- Zero-cost reopen of the senses list; consistent dots behaviour across the two fields.
- Photo descriptions are stored as `definition`, no longer discarded.

**Negative**
- Three more fields per row and a schema regeneration; the senses JSON must be dropped when the word changes (as translation options are today), while the definition text itself is kept (spec §8, resolved 2026-09-27).

**Neutral**
- Moving the senses to memory-only later is a one-field removal.

## Links

- Spec: [[../spec.md]] US-03..US-06, AC-09, AC-13
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0002-proxy-dictionary-lookups-through-the-worker]]
