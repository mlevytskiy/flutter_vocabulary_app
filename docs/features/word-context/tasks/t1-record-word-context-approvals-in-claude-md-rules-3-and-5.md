---
id: T1
title: "Record word-context approvals in CLAUDE.md rules 3 and 5"
layer: "docs"
deps: []
acs: ["AC-13"]
files_hint: ["CLAUDE.md"]
owner: "implementer agent"
estimate: "S"
status: "done"
---

# T1 — Record word-context approvals in CLAUDE.md rules 3 and 5

## Why

Derives from [AC-13](../spec.md); the owner approved the model change (B2) and the popup line (B10).

## What

Edit `CLAUDE.md` only.

## Definition of Done

- [ ] CLAUDE.md rule 3 adds word-context (owner, 2026-10-30): the Words screen popup shows a word's context in italic with "from the source" / "written by AI"
- [ ] rule 5 adds `WordOrigin`, `SourceType`, `ContextKind`, `WordPair.origin/context/contextKind/contextTried`, `SessionSource.fullText` (owner B2, 2026-10-30), no packages
- [ ] `flutter analyze` clean

## Notes

—
