---
id: T3
title: "Add the pure collection search: summaries, matching, filters, calendar-day ranges, sort and tag counts"
layer: "domain"
deps: ["T2"]
acs: ["AC-19", "AC-20", "AC-20b", "AC-21", "AC-23", "AC-25", "AC-37", "AC-38"]
files_hint: ["lib/core/services/collection_search.dart", "test/collection_search_test.dart"]
owner: "agent"
estimate: "M"
status: "todo"
---

# T3 — Add the pure collection search: summaries, matching, filters, calendar-day ranges, sort and tag counts

## Why

Derives from [ADR-0005](../adr/0005-derive-created-time-from-the-collection-id-and-keep-updatedat-as-edited-time.md), [ADR-0006](../adr/0006-search-and-filter-collections-in-memory-over-summaries-re-read-after-each-store-write.md), sad §6 Flow 8.

## What

`CollectionSummary` (id, name, description, originTags, topicTags, sourceTagKeys per kind, folderPath, treeIndex, created, edited). `CollectionFilter` (query, origin/topic tags, created/edited `DateChoice` incl. custom range, sort). `searchCollections(summaries, filter, now)` (substring on name/description/tags ignoring case; AND of all tags by kind; local calendar-day ranges; sorts My order/Name/Recently edited/Recently created). `rangeProblem(start,end)`. `tagCounts(summaries, kind)` (live collections, most used then A–Z). `useCounts(summaries)` for the library (collection or any source, counted once).

## Definition of Done

- [ ] unit tests for every AC listed, incl. 'Last 7 days' = today + 6 days and a custom range including its whole end day
- [ ] search over 500 summaries / 2,000 tags returns ≤ 100 ms in a timed test (spec §6)
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
