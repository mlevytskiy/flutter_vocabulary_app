---
id: T23
title: "Show the stored title as the shared page's heading and document title, escaped, with Vocabulary as the fallback"
layer: "ui"
deps: ["T22"]
acs: ["AC-29", "AC-30", "AC-33"]
files_hint: ["vocab-photo-api/src/session/page.ts", "vocab-photo-api/test/page.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T23 — Show the stored title as the shared page's heading and document title, escaped, with Vocabulary as the fallback

## Why

[screens SCR-14](../screens.md), [contracts/openapi.yaml](../contracts/openapi.yaml) `getSessionPage`, spec §6.1 abuse cases.

## What

- Reuses the existing `header.title` markup and `flex-wrap` header; no style change beyond the text.
- Grep `page.ts`, `client/`, `learn/` for visible "session" (the api stage found none) and fix any found.

## Definition of Done

**Done when:** Page tests cover SCR-14 default·named, before this feature, markup in the name and long name: `<h1>` and `<title>` show the title through `escapeHtml`, NULL shows "Vocabulary", `<b>x</b>` renders as text, a 60-character name wraps without sideways scroll, nothing about folders or other collections is in the page, and no visible "session" text remains.

- [ ] listed SCR-14 states covered
- [ ] `npm test` and `tsc` clean in `vocab-photo-api/`

## Notes

web-frontend surface; shares the Worker lane with T21–T22.
