---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0002 — Render the table on the server and enhance it with plain JavaScript

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The Worker renders the shared page today as a template string with inline CSS and no client JavaScript (`src/session/page.ts`). The feature adds in-place editing with save-on-leave, conflict choice, Undo, polling for other partners' changes, a photo pager with row highlighting, a swipe-and-zoom photo dialog, and per-cell and per-column autofill (spec US-05 – US-10) — all of which need code in the browser.

## Decision drivers

- spec §6: first render p95 ≤ 2.0 s to a readable table, 100 rows, phone on 4G; no page-level sideways scroll at 360 px.
- AC-36: switch between the phone and the wide layout by screen width alone, at once, without reload and without losing typed text.
- CLAUDE.md rule 5 / sad §2: no new packages without asking; the Worker has no runtime npm dependencies and no bundler.
- AC-33 / spec §6.1: every value shown as text, never as markup.

## Considered options

1. **Server-rendered table + plain-JavaScript enhancement** — the Worker renders the complete table as today; one framework-free script, served by the Worker, adds editing and the rest on top.
2. **Client-side SPA on a small framework (Preact or Lit)** — the Worker serves a shell and the data; the browser builds the table.

## Decision outcome

**Chosen:** option 1. The table is readable before any script runs, which is the surest path to the 2.0 s first-render target; the two layouts are CSS media queries on one DOM, so a width change never re-renders or loses typed text; and no package or build step is added.

## Consequences

**Positive**
- First render depends only on HTML + CSS; the script loads after and can fail without hiding the list.
- No new dependency; the script ships as a text module the Worker serves with a long cache lifetime.

**Negative**
- Table state (unsaved cells, conflicts, pending deletes, remote updates) is managed by hand in the DOM — roughly 600–900 lines of JavaScript that need one state object and a strict "textContent only, never innerHTML" rule.
- Without a bundler the script is written as JavaScript with JSDoc types, checked by `tsc` (`checkJs`), not as TypeScript.

**Neutral**
- Moving to a framework later means rewriting the client script, not the Worker's API — the contract (ADR-0004, ADR-0005) is framework-neutral.

## Links

- Spec: [[../spec.md]] US-01 – US-10, AC-33, AC-36, §6
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0005-poll-for-changes-since-the-last-seen-revision]]
