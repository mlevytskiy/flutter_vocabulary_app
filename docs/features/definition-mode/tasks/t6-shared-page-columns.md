---
id: T6
title: "Render shared-page columns from the detail mode"
layer: "ui"
deps: ["T5"]
acs: ["AC-16", "AC-17", "AC-18"]
files_hint: ["vocab-photo-api/src/session/page.ts"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T6 — Render shared-page columns from the detail mode

## Why

Derives from [ADR-0004](../adr/0004-record-the-detail-mode-in-the-published-session.md), [spec US-08, AC-16..AC-18](../spec.md) and [sad §5 page.ts](../sad.md).

## What

The page picks columns from `detail`: translation → word + translation (today's page); definition → word + definition; both → all three. Missing `detail` → translation. Definitions go through the existing `escapeHtml`. When definitions are shown, add "Definitions: Merriam-Webster" attribution. Reuses the existing table markup and styles.

## Definition of Done

- [ ] `npm run typecheck` clean.
- [ ] Against `wrangler dev`: pages for each of the three modes show the right columns; a document stored without `detail`/`definition` renders exactly as before; a definition containing `<script>` renders as text.
- [ ] An unknown session id still reveals nothing (AC-18).
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

—

## Verification (2026-09-27, `wrangler dev`)

- RED: a `detail: definition` session rendered `Word | Translation` before the change.
- After: definition → `# | Word | Definition` + "Definitions: Merriam-Webster"; both → `# | Word | Translation | Definition` + credit; a request without `detail` → `# | Word | Translation`, no credit (unchanged page, AC-17).
- A definition containing `<script>alert(1)</script>` renders as escaped text.
- Unknown session id → 404 "This word list is gone" (AC-18). `tsc --noEmit` exit 0.
