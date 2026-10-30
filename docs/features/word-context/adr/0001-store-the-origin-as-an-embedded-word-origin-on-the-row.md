---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "M"
ticket: "word-context"
---

# 0001 — Store the origin as an embedded WordOrigin on the row

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Architect (Claude Opus 5.5), the owner's picks and the Fable 5.1 owner proxy

## Context

Each word needs a source type, a per-type detail and a context (owner B2: one embedded object plus a context field).

## Decision drivers

- AC-01, AC-14
- rule 5 (approved by the owner, B2)
- Isar embedded rows

## Considered options

1. `@embedded WordOrigin` on `WordPair` + `context`, `contextKind`, `contextTried` on the row (chosen)
2. Flat fields on the row
3. A JSON string

## Decision outcome

Chosen: Option 1. `WordOrigin {SourceType typeOfSource; String movieName; int? season; int? episode; String time; bool wasTranslationEditByUser; bool wasDescriptionEditByUser}`; `time` as `hh:mm:ss` text (empty = unknown). `WordPair.context`, `WordPair.contextKind` (`ContextKind.none/source/ai`), `WordPair.contextTried` (backfill marker). `SessionSource.fullText` for photos. Enum names stored by name and pinned.

## Consequences

- + typed, testable, queryable
- − every WordPair copy path must carry the fields (AC-14 tests)
