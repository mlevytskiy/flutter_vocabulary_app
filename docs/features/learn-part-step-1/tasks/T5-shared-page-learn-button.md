---
id: T5
title: "Add Learn to the shared page with a fresh check before opening"
layer: "ui"
deps: ["T3"]
acs: ["AC-08", "AC-10"]
files_hint: ["vocab-photo-api/src/session/page.ts", "vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/style.ts", "vocab-photo-api/test/page.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T5 — Add Learn to the shared page with a fresh check before opening

## Why

[sad §4](../sad.md) "No words to learn" bullet and §6 S-03; [screens.md](../screens.md) SCR-05 (default phone/wide, empty, success phone/wide, error); [ADR-0001](../adr/0001-change-the-app-the-worker-and-the-shared-page-as-three-surfaces.md).

## What

- `src/session/page.ts` — the Learn link in `.actions`, after Download, same `.btn` look.
- `src/session/client/page.js` — click handler: in the wide layout (`WIDE`) `window.open('', '_blank')` synchronously; fetch changes since the last seen revision and apply them as the poller does; count words to learn among saved rows only (unsaved cells do not count); then toast + close the empty tab, or navigate/assign the tab's location.
- `src/session/style.ts` — only if `.actions` needs a rule to keep Download, Learn and the photo button on a 320 px phone (sad §11 risk).

## Definition of Done

**Done when:** The shared page's `.actions` row shows `<a class="btn learn" href="/s/:id/learn">Learn</a>` right of "Download for AnkiDroid" (covered by `test/page.test.mjs`), and a press in `page.js` first fetches `GET /s/:id/changes`, then shows the toast "No words to learn" without navigating when the fresh saved rows hold none, otherwise opens `/s/:id/learn` in the same tab below 900 px and in a tab opened empty during the click at 900 px and wider, falling back to the held rows when the fetch fails.

- [ ] `test/page.test.mjs`: the link is present, after Download, with the session's id
- [ ] manual check in `wrangler dev`: phone width → same tab, back returns to the shared page; wide → new tab, the shared page and an unsaved cell stay; delete every row on the page then press Learn → toast, no navigation, the empty tab closes (AC-10); offline → falls back to held rows
- [ ] the `.actions` row at 320 px does not overflow
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Reuses the existing public `GET /s/:id/changes` (good-looking-web ADR-0005) — no new route.
- CLAUDE.md rule 3 override: this button is one of the two approved visible changes (sad §2).
