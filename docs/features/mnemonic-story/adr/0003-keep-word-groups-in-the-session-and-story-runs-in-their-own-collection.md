---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — mnemonic story (after learn-part-step-1)"
---

# 0003 — Keep word groups in the session and story runs in their own collection

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

The feature keeps word groups, the selected group, mnemonic stories and story runs on the phone (spec §1: the owner narrowed "the learn page saves nothing"). CLAUDE.md rule 5 forbids new domain models without the owner's approval, and the spec says that approval is given here. A group must follow its own words through edits: a deleted word leaves it, and an edited English word shows its new form (AC-17). Neither the word text nor the row's position can do that. `WordPair` has no stable id today. Story runs are listed across all sessions, newest first, and are never removed (AC-14, AC-15). A History session keeps its own groups and stories (AC-11).

## Decision drivers

- ≤ 500 ms from Start to the saved picture and text shown (spec §6 "Saved story open time"; sad §1 quality goal 3).
- ≤ 3 MB on the device per story run, picture included (spec §6 "Storage").
- Groups follow the session's lifetime and its History entry (AC-11); runs outlive any group (AC-15).
- Isar is pinned to `3.3.0-dev.1`, and additive schema changes are the safe kind (architecture.md §2 rule 6).

## Considered options

1. **Groups embedded in `Session`, runs in their own collection** — `WordGroup` is `@embedded` in `Session`, and `StoryRun` (with embedded `StoryStep`s) is a new `@collection`. `WordPair` gains `rowId`. Pictures are files.
2. **Everything in separate collections** — `WordGroup`, `MnemonicStory` and `StoryRun` as three collections keyed by `sessionId`. `Session` is unchanged except `WordPair.rowId`.
3. **No new models** — groups, stories and runs as JSON in `shared_preferences`.

## Decision outcome

**Chosen:** Option 1. Groups live and die with their session, so embedding them keeps a History session's groups with it and needs no cross-collection clean-up. Runs are app-wide and permanent, so they are their own collection with an index on start time for the newest-first list. A group's mnemonic story is simply the run its `storyRunId` names, so no separate story model is needed. `WordPair.rowId` is a UUID made with the existing `_uuidV4` helper and filled in once for older rows when a session is read. The picture is compressed to ≤ 3 MB and stored as a file under `mnemonic_pictures/`, with only its path in the run. **This is the owner's approval under CLAUDE.md rule 5 for `WordGroup`, `StoryRun`, `StoryStep` and `WordPair.rowId`, given on 2026-10-07.** Option 3 would put about 100 MB a year of records into one preferences string and put the 500 ms open time at risk.

## Consequences

**Positive**
- Opening a saved story is one Isar read plus one local file. There is no network.
- A History session carries its groups, which satisfies AC-11 with no extra lookup.
- Story runs survive story replacement and group changes (AC-15).

**Negative**
- `Session` grows by its groups and the grouping key, and every save writes them too. That stays small: at most a few dozen groups of short strings.
- An Isar schema change ships to users' phones. It is additive, but it cannot be undone without an app update, and the `rowId` fill-in runs once per older session.

**Neutral**
- Moving groups into their own collection later needs a one-time copy on first launch.

## Links

- Spec: [[../spec.md]] §1, AC-07, AC-11, AC-14, AC-15, AC-16, AC-17, §6
- SAD: [[../sad.md]] §2, §4, §5
- Related ADR: [[0005-let-the-app-own-the-grouping-rules-and-the-ai-only-split-words]]
