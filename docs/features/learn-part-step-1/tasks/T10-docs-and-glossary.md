---
id: T10
title: "Update the repo docs this design outdates"
layer: "docs"
deps: ["T4", "T5", "T7", "T9"]
acs: []
files_hint: ["docs/architecture.md", "CLAUDE.md", "vocab-photo-api/README.md", "docs/features/learn-part-step-1/CONTEXT.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T10 — Update the repo docs this design outdates

## Why

[sad §11](../sad.md) risk row "Repo texts this design outdates"; [sad §12](../sad.md) flags "exercise list" and "pick" for the glossary.

## What

- Edit the four files named in `files_hint`. Wording only; no code.

## Definition of Done

**Done when:** `docs/architecture.md` lists `lib/features/learn/`, `LearnRoute`/`ComingSoonRoute` and `vocab-photo-api/src/learn/`; CLAUDE.md rule 5 names `Exercise` as approved and rule 3 names the two approved visible changes; `vocab-photo-api/README.md` documents `GET /s/:id/learn`, `GET /s/:id/learn/:exercise` and `/assets/learn-<hash>.js`; the feature CONTEXT.md defines "exercise list" and "pick".

- [ ] `grep -n "features/learn\|src/learn" docs/architecture.md` finds the new entries
- [ ] `grep -n "Exercise" CLAUDE.md` finds the rule-5 approval
- [ ] `grep -n "/learn" vocab-photo-api/README.md` finds both routes and the asset
- [ ] `grep -n "exercise list\|pick" docs/features/learn-part-step-1/CONTEXT.md` finds both terms under `## Glossary`

## Notes

- CLAUDE.md edits are the owner's call — keep them to the minimal sentences sad §2 names.
