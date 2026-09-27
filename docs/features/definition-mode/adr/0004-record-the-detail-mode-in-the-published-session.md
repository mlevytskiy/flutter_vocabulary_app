---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/tasks/active/task-19-definition-mode-setting.md"
---

# 0004 — Record the detail mode in the published session

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The partner must see definitions as the learner's mode showed them at publishing time (AC-16), links published before this feature must keep working (AC-17), and the page's AnkiDroid download must match the learner's export (AC-20). Stored session documents live 30 days in KV, so their shape outlives app versions. The current Worker's `parseEntries` keeps only `word` and `translation`, silently dropping anything else.

## Decision drivers

- Quality goal 1: data integrity and compatibility across app and Worker versions.
- Owner's rule: the page shows and hides columns according to the mode.
- Spec §6: definitions bounded by the same per-field limit as translations (500 characters).

## Considered options

1. **Mode in the document** — entries gain an optional `definition`; the session document gains `detail` (translation / definition / both); the page and its download pick columns from `detail`; a document without `detail` is read as translation.
2. **Page infers columns from the data** — show a column if any entry has that field; no document field.

## Decision outcome

**Chosen:** option 1. The page shows exactly what the learner's mode showed, and old documents render exactly as today. The Worker validates `definition` with the 500-character limit and treats a row as blank only when word, translation and definition are all empty. **Deploy order: Worker first, then the app** — an older Worker would silently drop definitions.

## Consequences

**Positive**
- The page mirrors the learner's mode; no guessing from leftover data.
- Backward compatible: pre-feature documents need no migration.

**Negative**
- A new document field to validate and default; a deploy-order dependency (Worker before app).

**Neutral**
- A future "change mode after publishing" would need a re-publish; out of scope.

## Links

- Spec: [[../spec.md]] US-08, AC-16..AC-20
- SAD: [[../sad.md]] §4, §6
- Related ADR: [[0005-export-anki-files-with-a-fixed-definition-column]]
