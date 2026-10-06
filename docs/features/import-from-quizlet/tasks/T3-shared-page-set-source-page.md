---
id: T3
title: "Show a set source as a page of the source pager and the phone sources dialog"
layer: "ui"
deps: ["T2"]
acs: ["AC-13", "AC-14"]
files_hint: ["vocab-photo-api/src/session/page.ts", "vocab-photo-api/src/session/client/page.js", "vocab-photo-api/src/session/style.ts", "vocab-photo-api/test/page.test.mjs"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T3 — Show a set source as a page of the source pager and the phone sources dialog

## Why

spec AC-13, AC-14; [ux-flows](../ux-flows.md) SCR-06, SCR-07, SCR-08; [sad §6 F5](../sad.md); [sad §8](../sad.md) output escaping; good-looking-web ADR-0002.

## What

- `page.ts`: render a set slot as a pager page / dialog page with the name (`escapeHtml`) and the link; the stacked-thumbnail button counts sets too.
- `client/page.js`: the pager and dialog treat a set slot like a photo slot without an image; row highlighting by `sourceId` unchanged; text via `textContent` only.
- `style.ts`: the set page's layout, reusing the pager's existing classes.

## Definition of Done

**Done when:** On a session published with two photos and one set, the wide pager shows the set's name as text with its plain link under it and "3 of 3", highlights only that set's rows, the phone sources dialog has a page for it, the link opens in a new tab with `rel="noopener noreferrer"`, a name containing markup renders as text; covered by `test/page.test.mjs` and a manual check at 360 px and wide.

- [ ] `npm test` page cases pass (set page present, name escaped, link attributes, highlight data)
- [ ] `npm run typecheck` clean (covers `page.js` via `checkJs`)
- [ ] manual look at 360 px and at a wide window

## Notes

- No `screens.md` was produced for this feature; follow the existing photo page of the pager and the ux-flows inventory. The set page's exact look and the set tile in the thumbnail stack are open for the owner at review.
