---
id: T1
title: "Record the owner's approvals for collections-screen in CLAUDE.md rules 3 and 5"
layer: "docs"
deps: []
acs: []
files_hint: ["CLAUDE.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T1 — Record the owner's approvals for collections-screen in CLAUDE.md rules 3 and 5

## Why

Every later task adds approved new data or visible changes; implement agents stop on CLAUDE.md rules 3 and 5 unless the approval is written there. Source: [spec §1](../spec.md#1-context) decisions 1 and 8, [sad §2](../sad.md#2-constraints) Conventions.

## What

- Append a collections-screen clause to rule 3's approved list, in the same style as the existing clauses: the Collections screen, recycle bin, the edit button beside the main screen's title, the name as the title, the always-present side menu with Collections, ⋮ on every icon, the bin drop zone, the name in History rows / shared page / shared files, the share sheet's name warning, "collection" replacing "session" in text.
- Add to rule 3 that the session → collection rename is an approved exception to "move code, do not rewrite it" ([ADR-0002](../adr/0002-rename-session-to-wordcollection-with-stored-names-pinned.md)).
- Append to rule 5's approved list: `Session` renamed `WordCollection` with the six filing fields, and the new `CollectionFolder` Isar collection (ADR-0003, ADR-0004, ADR-0005). No packages.

## Definition of Done

**Done when:** CLAUDE.md rule 3 lists every visible change spec §1 approves (last decision) and the rename exception, and rule 5 lists `WordCollection` (renamed `Session`) with `name`, `folderId`, `order`, `binnedAt`, `binnedFromFolderId`, `keep`, and `CollectionFolder`, each tagged collections-screen (owner, 2026-10-16), so later tasks do not stop on rule 3 or 5.

- [ ] Rule 3 and rule 5 each name collections-screen with the owner and date
- [ ] No other rule text changed

## Notes

Text only. Do this first so implement's rule check passes for every later task.
