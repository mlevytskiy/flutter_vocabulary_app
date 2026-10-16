---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0001 — Store typed tags as separate origin and topic lists beside the legacy list

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

Every tag now has a kind: origin ("Where does it come from?") or topic ("What is it about?"), on a collection and on each source (spec US-01..US-06, AC-11). Today both `WordCollection.tags` (`word_collection.dart:74`) and `SessionSource.tags` (`session_source.dart:54`) are untyped `List<String>`. Isar cannot reinterpret a stored field's type, so changing `tags` in place would make the old values unreadable before the migration could sort them (failure-mode V2).

## Decision drivers

- The migration must lose no tag (spec §6 "Migration accuracy", AC-17).
- The same text can be both an origin tag and a topic tag (AC-11).
- Search, filter, the tag line and the editors read tags of one kind at a time (AC-13, AC-20, AC-34).
- New data was approved by the owner (rule 5): typed tags on `WordCollection` and `SessionSource`.

## Considered options

1. **Two plain lists per owner** — `originTags` and `topicTags` (`List<String>`) on `WordCollection` and on `SessionSource`. The legacy `tags` stays as is.
2. **One embedded list of `{kind, text}`** — a new `@embedded TypedTag` list replaces the untyped list under a new stored name.

## Decision outcome

**Chosen:** option 1. Each screen reads one kind directly, the existing `TagEditor` keeps taking a `List<String>`, and JSON stays flat. The kind is the field, so "same text in both kinds" needs no special rule. Option 2 needs a new embedded type, filtering on every read, and the same legacy field anyway.

`fromJson`/`toJson` gain `originTags`/`topicTags` (omitted when empty for sources, as `tags` is today). `copy()` copies both lists.

## Consequences

**Positive**
- Simple reads, simple JSON, and the editors take a plain list per kind.
- The legacy field stays readable for the migration (ADR-0003).

**Negative**
- Four new stored lists plus two legacy ones that stay in the schema, emptied.

**Neutral**
- A third kind later would mean a third list per owner.

## Links

- Spec: [[../spec.md]] AC-11, AC-13, AC-17, AC-34
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0003-migrate-untyped-tags-once-on-store-open-and-empty-the-legacy-lists]]
