---
id: T3
title: "Serve the web learn page, the no-words page and the coming-soon page from the Worker"
layer: "ports"
deps: ["T1"]
acs: ["AC-04", "AC-06", "AC-08", "AC-08b", "AC-09"]
files_hint: ["vocab-photo-api/src/learn/page.ts", "vocab-photo-api/src/learn/routes.ts", "vocab-photo-api/src/index.ts", "vocab-photo-api/src/session/style.ts", "vocab-photo-api/test/learn.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T3 — Serve the web learn page, the no-words page and the coming-soon page from the Worker

## Why

[openapi.yaml](../contracts/openapi.yaml) `getLearnPage`, `getComingSoonPage`; [ADR-0002](../adr/0002-render-the-web-learn-page-on-the-worker-and-keep-ticks-in-its-link.md); [sad §6](../sad.md) S-04; [screens.md](../screens.md) SCR-06 (default, coming-soon tap, returned, empty, error), SCR-07 (default, error, empty), SCR-08.

## What

- `src/learn/page.ts` — `renderLearnPage`, `renderNoWordsPage`, `renderComingSoonPage` inside the shared page's `shell()`; every stored value through `escapeHtml`; native `<input type="checkbox">` in a `<label>`, coming-soon ones `disabled` with `.soon` and "Coming soon"; Start as `a.btn` with `aria-disabled` and the hint "Pick at least one exercise" in an `aria-live` region; word count "1 word" / "<n> words" as on the shared page.
- `src/learn/routes.ts` — the two routes, reusing `loadSession`, `renderNotFoundPage`, `pageHeaders()`, `htmlResponse`; `pick` (repeatable) ignored unless it names an available exercise.
- `src/index.ts` — add the learn routes to the route table.
- `src/session/style.ts` — `.exercise` / `.soon` rules and the one-column layout (no sideways scroll at 320 px). One stylesheet, one CSP hash.

## Definition of Done

**Done when:** `GET /s/:id/learn` and `GET /s/:id/learn/:exercise` are registered `public: true` and answer as `getLearnPage` / `getComingSoonPage` in openapi.yaml: 200 learn page with the word count and eleven exercises (ticked only for a valid `pick`), 200 no-words page with a link to `/s/:id`, 200 coming-soon page for `mnemonic-story`, and the byte-identical 404 gone page for a dead session or an unknown/unavailable exercise; covered by `test/learn.test.mjs`.

- [ ] learn page lists `exercises.json` in order with stage headings "Step 1/2/3" and states; nothing ticked without `pick`; `?pick=mnemonic-story` renders it `checked`; `?pick=match-synonyms` and `?pick=nope` render nothing ticked (AC-06)
- [ ] no-words page for a live session whose saved rows hold no word to learn (deleted rows do not count)
- [ ] dead/unknown session on both routes, and `/learn/match-synonyms`, `/learn/nope` → status, headers and body identical to `GET /s/<unknown id>` (AC-09, QG-4)
- [ ] HTML answers are `no-store` and carry the unchanged CSP; a stored word containing markup renders as text
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- **OQ-1 (api-sync-report.md) is still open:** coming-soon page for a live session with no word to learn. Build the contract's **provisional** answer (200 coming-soon page) and leave a `// OQ-1` comment at that branch; if the owner resolves it the other way before this task runs, follow the resolution and update openapi.yaml + screens.md SCR-07.
- Shares `src/learn/page.ts` with T4 and `src/session/style.ts` with T5 → serialized lanes.
- The `<script>` tag for `learn.js` is added in T4, not here.
