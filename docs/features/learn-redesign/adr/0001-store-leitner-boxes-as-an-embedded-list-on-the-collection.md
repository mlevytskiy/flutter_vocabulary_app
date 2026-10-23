---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0001 — Store Leitner boxes as an embedded list on the collection

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

A word's Leitner box must survive app restarts, follow its collection into and out of the recycle bin (spec AC-15) and vanish with its row. The app already keeps per-word learn data (`WordResult`) as an embedded list on `WordCollection`.

## Decision drivers

- AC-15: box per row of one collection; bin restore brings boxes back
- rule 5: one new model, approved by the owner
- existing pattern: `WordCollection.results`

## Considered options

1. Embedded `WordBox` list on `WordCollection` (chosen)
2. A new Isar collection `WordBox` keyed by collection id + row id
3. Fields on `WordPair` (the row)

## Decision outcome

Chosen: option 1. Add `@embedded class WordBox {rowId, word, box, dueAt, lastUpDay}` and `List<WordBox> boxes` on `WordCollection`, written only through `CollectionStore.update`. A box matches a row when both rowId and the trimmed lower-case English word match; otherwise the row is new. Binned/restored collections carry their boxes for free.

## Consequences

- + no join, no orphan cleanup: a deleted row's box is ignored and pruned on the next session write
- + binning/restoring needs no code
- − a row edit of the English word silently resets the box (wanted by AC-15)
- − `put` from the words table must not overwrite boxes: `put` copies `boxes` from the stored record like the protected fields
