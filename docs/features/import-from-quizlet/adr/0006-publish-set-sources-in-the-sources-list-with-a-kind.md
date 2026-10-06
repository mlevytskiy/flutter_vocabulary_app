---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "M"
ticket: "import-from-quizlet"
---

# 0006 — Publish set sources in the sources list with a kind

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

A publish today sends `sources: [{id, order}]` — declared photos whose bytes follow (good-looking-web ADR-0006) — and the Worker keeps photo slots in the D1 `sources` table (pending → arrived), capped at `MAX_SOURCES` 10. `SessionSource` in `src/session/types.ts` was designed for "another `kind`, never a top-level field". Set sources must be published (AC-13, AC-14), hidden with the switch (AC-12), counted once (AC-13b), and no longer limited in number (spec §1 decision).

## Decision drivers

- sad §1 quality goal 3: one switch for all sources.
- spec §6 "Sources per published session: no limit" and §6.1 "only accepts a Quizlet set link as a set source".
- The Worker never contacts Quizlet (sad §3); its check is format-only.
- ADR-0005: the app already keeps one ordered list with a `kind`.

## Considered options

1. **The same `sources` list with a `kind`** — `{id, order, kind: "photo"}` or `{id, order, kind: "set", name, url}`; a missing `kind` means photo; D1 `sources` gains `kind`, `name`, `url`; a set slot is "arrived" at once (no bytes).
2. **A separate `sets` field and table** — a new top-level field in the publish and a `set_sources` table, photo slots untouched.

## Decision outcome

**Chosen:** Option 1. It follows the Worker's own rule for new source kinds and the app's one list (ADR-0005), and keeps the pager's order a single `ord` column. `MAX_SOURCES` is removed: the real bound is that a source is declared only when a row links to it, so at most `MAX_ENTRIES` (500) sources, inside `MAX_SESSION_JSON_BYTES` (256 KB). The Worker checks a set source's `url` is a plain Quizlet set address (`https://quizlet.com/<digits>/<slug>/`, no query) and its `name` is plain text within `MAX_FIELD_CHARS`; the page shows the name as text and the link with `rel="noopener noreferrer"` in a new tab.

## Consequences

**Positive**
- Older app builds keep publishing unchanged (no `kind` = photo).
- The pager, the phone sources dialog and the change feed treat a set as one more slot.

**Negative**
- A D1 migration (`kind`, `name`, `url` on `sources`) and every photo-only query (upload to a declared id, serving bytes) must filter `kind = 'photo'`.
- A new app build publishing to an old Worker would be refused on the `kind` field — the Worker must be deployed first (sad §7).

**Neutral**
- The upload route refuses bytes for a set slot; serving `/s/<id>/sources/<setId>` answers not found.

## Links

- Spec: [[../spec.md]] AC-12, AC-13, AC-13b, AC-14, AC-15, §6, §6.1
- SAD: [[../sad.md]] §3, §4, §5
- Related ADR: [[0005-keep-photos-and-sets-in-one-source-list-with-a-kind]]; good-looking-web ADR-0006
