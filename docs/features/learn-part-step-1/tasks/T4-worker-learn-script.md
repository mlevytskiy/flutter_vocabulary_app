---
id: T4
title: "Add learn.js: Start, the hint, the pick in the address and Back to exercises"
layer: "ui"
deps: ["T3"]
acs: ["AC-05", "AC-05b", "AC-07"]
files_hint: ["vocab-photo-api/src/learn/client/learn.js", "vocab-photo-api/src/learn/client/learn.d.ts", "vocab-photo-api/src/session/assets.ts", "vocab-photo-api/src/learn/page.ts", "vocab-photo-api/tsconfig.client.json", "vocab-photo-api/test/learn.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T4 — Add learn.js: Start, the hint, the pick in the address and Back to exercises

## Why

[ADR-0002](../adr/0002-render-the-web-learn-page-on-the-worker-and-keep-ticks-in-its-link.md); [openapi.yaml](../contracts/openapi.yaml) `getLearnScript`; [sad §4](../sad.md) choice 2, §5; [screens.md](../screens.md) SCR-06 (ticked, unticked again, no script), SCR-07 (back).

## What

- `src/learn/client/learn.js` — plain JS with JSDoc: on change, toggle Start (`aria-disabled`, `href`), the hint, and `history.replaceState` with `?pick=` (removed when nothing is ticked); Start ignores clicks while unavailable; on the coming-soon page, "Back to exercises" uses `history.back()` when the previous entry is this session's learn page, else follows its `href`.
- `src/learn/client/learn.d.ts` — the Text-module import's type, like `session/client/page.d.ts`.
- `src/session/assets.ts` — hash and serve `learn-<hash>.js` beside `page-<hash>.js`.
- `src/learn/page.ts` — add the `<script src>` for the hashed URL.
- `tsconfig.client.json` — include `src/learn/client/*.js`.

## Definition of Done

**Done when:** `/assets/learn-<hash>.js` is served with the same immutable caching as `page-<hash>.js` and loaded by both learn pages under the unchanged CSP; ticking Mnemonic story enables Start (its `href` → `/s/:id/learn/mnemonic-story?pick=mnemonic-story`), hides the hint and rewrites the address with `?pick=` via `replaceState`, unticking reverses all three, and `npm run typecheck` checks `learn.js`; serving and the script tag are covered by `test/learn.test.mjs`.

- [ ] `GET /assets/learn-<hash>.js` → 200 `text/javascript`, immutable one-year cache; a wrong hash → 404
- [ ] both learn pages reference the hashed URL; `script-src 'self'` unchanged, no inline script
- [ ] manual check in `wrangler dev`: tick → Start enabled + hint hidden + address has `?pick=mnemonic-story`; untick → back; Start → coming-soon; Back to exercises and the browser back button both land on the learn page with Mnemonic story ticked (AC-05); the Learn link (no pick) opens unticked (AC-05b)
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Without JavaScript the page renders `default` and Start stays unavailable — accepted debt (sad §11).
- Start opens the coming-soon page for the first ticked exercise in plan order (sad §11 accepted debt).
