---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "S"
ticket: "learn-part-step-1"
---

# 0002 — Render the web learn page on the Worker and keep ticks in its link

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The spec already rules out the app's code built for the browser: the web learn page is "an ordinary page served beside the shared page, with its own link" (spec §1, owner decision 2026-10-06). What remains open is who holds the ticks and whether the page needs JavaScript. The ux-flows platform decisions flag the hard part. On the web, "Back to exercises" and the browser's back button must return from the coming-soon page to the learn page with Mnemonic story still ticked (AC-05). A Learn button must still open it unticked (AC-05b). Every page answer is `cache-control: no-store`, under a CSP with `script-src 'self'` (no inline script) and `form-action 'none'`.

## Decision drivers

- AC-05 on the web: ticks survive the round trip to the coming-soon page and back, including the browser's back button.
- AC-05b and AC-06: a new visit from Learn starts unticked, and a coming-soon exercise can never be ticked or started.
- Spec §6: ≤ 1.5 s to the page shown on a phone over 4G, and no sideways scrolling at 320 px.
- sad §2: the shared page's existing CSP, `no-store` and server-rendered-plus-plain-JS shape (good-looking-web ADR-0002). No runtime npm dependencies in the Worker.

## Considered options

1. **Server-rendered pages plus a separate `learn.js`, with ticks mirrored into the link.** The Worker renders `/s/:id/learn` and `/s/:id/learn/:exercise` as complete HTML. `learn.js`, served at `/assets/learn-<hash>.js`, toggles Start and the hint and writes the ticks into the address with `history.replaceState` (`?pick=mnemonic-story`). The browser's back button lands on that address, which the server renders ticked.
2. **No JavaScript: an HTML form plus CSS `:has()`.** The tick boxes submit a GET form to the coming-soon page, and Start's unavailable look and the hint come from `:has(input:checked)`. The CSP's `form-action` must open to `'self'` for these pages. Ticks after "back" depend on the browser restoring form state, which `no-store` pages often skip.
3. **The learn page's logic inside the shared page's `page.js`.** This means one script for both pages and no second asset route, but the learn page loads the 1,800-line table-editing script, and the back-button problem still needs option 1's link scheme.

## Decision outcome

**Chosen:** Option 1. It is the only option where the ticks after "back" come from the address, which the server controls, rather than from browser cache behaviour that `no-store` makes unreliable. It keeps the CSP unchanged and the page small. The details:

- The Learn button on the shared page is a plain `<a href="/s/:id/learn">`, with no `pick`, so every visit from Learn starts unticked (AC-05b).
- The server pre-ticks only exercises that are both named in `pick` and available. Anything else in `pick` is ignored (AC-06).
- Start goes to `/s/:id/learn/<first ticked exercise in plan order>?pick=…`. "Back to exercises" uses `history.back()` when the previous entry is this session's learn page, else it follows its link to `/s/:id/learn?pick=…`. So the history never grows a loop.
- `GET /s/:id/learn/:exercise` for an exercise that is unknown or not available, or for a dead session, answers with the 404 "gone" page (AC-09).

## Consequences

**Positive**
- The browser's back button keeps ticks on every browser, testable with a plain request to `/s/:id/learn?pick=mnemonic-story` in the Worker's `node --test` suite.
- The CSP and the shared page's script are untouched. The learn page carries only its own few kilobytes.
- Later exercises reuse the same link scheme. Several ticks become a repeated `pick`.

**Negative**
- A second script asset: `assets.ts` serves and hashes two files instead of one.
- Without JavaScript, Start does nothing, as editing on the shared page does nothing without it.

**Neutral**
- A learn link copied by hand with `?pick=` opens ticked. That is harmless: it only pre-ticks an available exercise and saves nothing.

## Links

- Spec: [[../spec.md]] AC-05, AC-05b, AC-06, AC-08, AC-08b, AC-09; §6 web load and 320 px rows
- SAD: [[../sad.md]] §4
- Related ADR: [[0001-change-the-app-the-worker-and-the-shared-page-as-three-surfaces]]; good-looking-web ADR-0002 (server-rendered page enhanced by plain JavaScript)
