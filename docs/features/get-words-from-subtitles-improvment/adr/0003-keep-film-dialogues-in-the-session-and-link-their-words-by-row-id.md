---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — get words from subtitles improvement (dialogues)"
---

# 0003 — Keep film dialogues in the session and link their words by row id

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

A film dialogue has its lines, the word rows linked to it at Done (which only shrink, AC-11), its place in the pager and, later, a scene picture. It must survive a restart and come back with its session from History (AC-10). A dialogue group must be usable by "Mnemonic story" too (AC-24), and a scene picture must appear in Story runs (AC-14). Spec §1 approves film dialogues and scene pictures as new session data under CLAUDE.md rule 5.

## Decision drivers

- Dialogues live and die with their session (AC-10; spec §6.1 "stored with the session").
- Edits follow the word through its stable `WordPair.rowId` (AC-11, AC-21, AC-26).
- Reuse: word groups and story runs already exist (mnemonic-story ADR-0003).

## Considered options

1. **Embedded in `Session`** — a new `@embedded FilmDialogue` (`id`, `lines`, `wordRowIds`, `scenePictureRunId`, push state) in `Session.dialogues`, in pager order; `WordGroup.dialogueId`; `StoryRun.kind` and `StoryRun.sceneText`.
2. **Own Isar collection** — `FilmDialogue` as a `@collection` keyed by `sessionId`, as `StoryRun` is.

## Decision outcome

**Chosen:** Option 1. A session and its dialogues are saved together, so Done writes words and dialogues in one put, and History, restart and deletion need no extra code. This is the same shape mnemonic-story chose for word groups. A separate collection would need two-collection writes to stay consistent, and cleanup when a session goes, for a benefit the spec does not ask for.

## Consequences

**Positive**
- Words and dialogues are always consistent in one save (AC-03, AC-10, AC-12).
- A dialogue group is a `WordGroup`, so the group pager, selection and "Mnemonic story" work on it unchanged.
- A scene picture is a `StoryRun`, so the tracker, picture store and story runs screens work on it unchanged.

**Negative**
- `Session` grows by a few KB per import with dialogues (≤ 10 × 8 lines).
- Isar schema change on three models; older sessions read with empty `dialogues`, `dialogueId` null and `kind` `story`.

**Neutral**
- Moving dialogues to their own collection later needs a one-time copy on first read.

## Links

- Spec: [[../spec.md]] §1 (rule 5 approval), AC-10, AC-11, AC-14, AC-24
- SAD: [[../sad.md]] §4, §5
- Related ADR: mnemonic-story ADR-0003; [[0004-draw-scene-pictures-as-two-step-runs-of-the-story-run-workflow]]
