---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0004 — Protect description and typed tags in put and write them only through store transactions

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

`put()` (`collection_store.dart:383-428`) copies content fields from the caller's copy. The main screen's autosave runs 500 ms after any change (`word_input_notifier.dart:591-603`), and stories, dialogue deliveries, learn results and late lookups also save copies they have held for a while. A description or a tag saved in the sheet could be undone silently by an older copy (failure-mode V1, AC-18). collections-screen ADR-0003 solved the same problem for filing by taking those fields from the stored record.

## Decision drivers

- "0 cases where a background save undoes a typed tag or description" (spec §6, QG-1).
- Copy-up from a source must respect the collection's current tags and the 10 cap at the moment it happens (AC-15, AC-29).
- Precedent and reviewer familiarity: collections-screen ADR-0003.

## Considered options

1. **Protected fields**: `put()` and `update()` copy `description`, `originTags`, `topicTags` from the stored record. Only `setDetails(id, name?, description?, origin?, topic?)`, `addCollectionTags(id, kind, tags) → notAdded`, `create(details)` and the migration write them, each as one transaction.
2. **Caller-copied (as `tags` is today)**, relying on the notifier being the only writer of the current collection.

## Decision outcome

**Chosen:** option 1. It closes AC-18 by construction for every writer, now and future. Option 2 depends on every background writer re-reading before saving, which is the bug class this app already hit with filing.

Consequences for callers:
- The Notes page's collection fields and the details sheet call the notifier, which calls `setDetails` at once, not debounced. It adopts the stored description, tags, `updatedAt` and `lastLocalModifiedAt` into its in-memory copy, so the tag line and the Notes chips update immediately. `put()` takes both times from the caller (`collection_store.dart:399-400`), and `markShared`, `updateDialogues` and `markDialoguesPublished` put the notifier's copy unstamped, so without this adoption a later put would roll the edited time back. A later autosave of that copy cannot write older values back, because `put()` ignores them. Tests pin both (owner condition, D4).
- `updateSourceNote` (today a sync `void` that ends in the debounced autosave, `word_input_notifier.dart:471-489`) becomes `Future<CopyUpResult>`. It saves the source through `store.update` at once. It diffs the source's tag lists, and each newly added tag goes to `addCollectionTags` in the same transaction, which touches the library. It adopts the stored sources, typed tags and times, and returns the kinds whose tags the 10 cap refused. The Notes page shows the AC-29 snackbar from that result.
- `setDetails` moves `updatedAt` and `lastLocalModifiedAt` only when a value actually changed (AC-06, ADR-0005).
- `setDetails` and `create(details)` set `keep = true` when they save a non-empty description or any typed tag, and never clear it, following the existing never-set-back rule. Leaving a collection then needs only today's `keep` check (AC-28, owner batch 6).

Implementation note (T5): `put()` also never moves `updatedAt` or `lastLocalModifiedAt` backwards: it keeps the later of the stored and the caller's time. Even a stale copy that wasn't adopted can't roll the edited time back.

## Consequences

**Positive**
- No writer can undo details through `put()`.

**Negative**
- Two more protected fields that every `put()` test must cover. The notifier must adopt stored values after each details save.

**Neutral**
- Source tags stay inside `sources`, which are caller-copied (§11 risk). Saving them at once plus adoption closes the window. A required test pins a source tag surviving the autosave (owner D11).

## Links

- Spec: [[../spec.md]] AC-06, AC-15, AC-18, AC-28, AC-29
- SAD: [[../sad.md]] §4, §6, §8
- Related ADR: collections-screen [[../../collections-screen/adr/0003-keep-filing-on-the-collection-row-written-only-by-store-transactions]]
