---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "M"
ticket: "import-from-quizlet"
---

# 0005 — Keep photos and sets in one source list with a kind

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The app keeps a session's source photos in `Session.sources` (`SourcePhoto`: id, fileName, takenAt) and links a row to its photo through `WordPair.sourceId` (good-looking-web). A set source must join them: a row has at most one source, a photo or a set (feature CONTEXT invariant); the pager shows photos and sets in one order ("3 of 3", AC-13); a set imported twice — from another link shape, after a rename — stays one source with the newer name (AC-13b). The set source is an approved new domain model (spec §1). Changing the Isar shape later means a data migration on every device.

## Decision drivers

- Feature CONTEXT: "source — a source photo or a set source"; "a word row has at most one source".
- AC-13 / AC-15: one ordered list of sources for the pager and one count for "Include sources (N)".
- AC-13b: one set, one source.
- ADR-0006: the Worker keeps one ordered `sources` list with a `kind`.

## Considered options

1. **A separate `setSources` list** — a new `@embedded SetSource` beside the untouched `SourcePhoto` list; the order across both comes from their timestamps.
2. **One source list with a `kind`** — generalise the embedded source into one type with a `kind` (photo | set) and kind-specific optional fields; photos and sets live in one ordered `Session.sources`.

## Decision outcome

**Chosen:** Option 2 (owner's choice). One ordered list in the app matches the domain ("a source is a photo or a set"), the Worker's list (ADR-0006) and the pager, so "Include sources (N)", the publish payload and the pager order need no merging. A set source's id is derived from Quizlet's set id (`quizlet-<setId>`), so a second import of the same set finds the existing entry, updates its name and keeps its place (AC-13b). Isar has no polymorphic embedded types, so the shape is one class with optional fields.

## Consequences

**Positive**
- One list, one order, one count everywhere; a third source kind later is one more `kind` value.
- `WordPair.sourceId` is reused unchanged.

**Negative**
- The photo path (`source_photo_store`, `photo_upload_service`, thumbnails, the share sheet, tests) is touched: every use must check `kind == photo` before reading `fileName` or uploading bytes — a regression risk in a finished feature (sad §11).
- Kind-specific fields are nullable, so "a photo has a file name" and "a set has a name and url" are rules in code, not in the type.

**Neutral**
- Existing sessions must keep reading: the stored embedded schema keeps its Isar name (`@Name`), new fields are nullable, and a missing `kind` reads as `photo` — no migration step.

## Links

- Spec: [[../spec.md]] §1 decision (new domain model), AC-13, AC-13b, AC-15
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0006-publish-set-sources-in-the-sources-list-with-a-kind]]
