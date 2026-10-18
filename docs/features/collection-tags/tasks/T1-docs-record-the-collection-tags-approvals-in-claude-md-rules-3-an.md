---
id: T1
title: "Record the collection-tags approvals in CLAUDE.md rules 3 and 5"
layer: "docs"
deps: []
acs: []
files_hint: ["CLAUDE.md"]
owner: "agent"
estimate: "S"
status: "todo"
---

# T1 — Record the collection-tags approvals in CLAUDE.md rules 3 and 5

## Why

Derives from sad §9 lists the proposed lines (owner via Fable 5.1 proxy, 2026-10-16).

## What

Add the rule-3 visible-change line and the rule-5 new-data line from [sad §9](../sad.md) to CLAUDE.md.

## Definition of Done

- [ ] CLAUDE.md rule 3 and rule 5 carry the collection-tags lines verbatim from sad §9
- [ ] `flutter analyze` clean, `tool/test.sh changed` green

## Notes

Follow CLAUDE.md (typed routes, providers, no new packages, move code by cut-and-paste). Lanes: tasks touching `collection_store.dart` (T4–T7) run in order; `collections_screen.dart` (T10, T13) and `word_input_screen.dart` (T10, T11) are shared.
