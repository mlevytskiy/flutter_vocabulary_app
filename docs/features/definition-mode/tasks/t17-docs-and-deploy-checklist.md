---
id: T17
title: "Update architecture docs and the deploy checklist"
layer: "docs"
deps: ["T4", "T5", "T6", "T7", "T16"]
acs: ["AC-17"]
files_hint: ["docs/architecture.md", "vocab-photo-api/README.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T17 — Update architecture docs and the deploy checklist

## Why

Derives from [sad §7 deployment, §11 deploy-order risk](../sad.md).

## What

`docs/architecture.md`: services list gains `DictionaryService`, providers gain `wordDetailModeProvider`, the §3 diagram gains the Settings → mode edge. Worker README: deploy checklist — create the `DEFINITIONS` KV namespace, `wrangler secret put MW_API_KEY`, deploy the Worker **before** installing the new app, then verify an old link still renders.

## Definition of Done

- [ ] Checklist followed once end to end on the real Worker; an existing pre-feature link renders unchanged (AC-17).
- [ ] Licence open question (sad §11) answered before this deploy.
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—
