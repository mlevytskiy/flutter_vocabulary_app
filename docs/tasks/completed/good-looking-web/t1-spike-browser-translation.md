---
id: T1
title: "Spike: get a translation from the free endpoint in the partner's browser"
layer: "tests"
deps: []
acs: ["AC-16", "AC-17"]
files_hint: ["vocab-photo-api/spike/translate.html", "docs/features/good-looking-web/adr/0007-call-the-translation-endpoint-from-the-partners-browser.md"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T1 — Spike: get a translation from the free endpoint in the partner's browser

## Why

[ADR-0007](../../../features/good-looking-web/adr/0007-call-the-translation-endpoint-from-the-partners-browser.md) is conditional on this spike; [sad §11](../../../features/good-looking-web/sad.md) rates the unverified CORS behaviour High. Acceptance criteria: [AC-16](../../../features/good-looking-web/spec.md), [AC-17](../../../features/good-looking-web/spec.md).

## What

A throwaway page served by `wrangler dev` calls `translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=uk&dt=t&q=<word>` with `fetch` and prints the parsed translation (same parsing rule as `lib/core/services/translate_response_parser.dart`). Try it in Chrome (desktop + Android) and Safari (macOS + iOS) against 20 words, including a misspelling. Record the outcome (CORS allowed? 429s? response shape) as a `## Spike result` note in ADR-0007. If the browser is blocked, stop and hand back: ADR-0007 must be superseded by the Worker-proxy option before T15.

## Definition of Done

- [x] The spike page returns translations for ≥18 of 20 words in Chrome and Safari, or the blocking error is quoted
- [x] ADR-0007 has a dated `## Spike result` section with the verdict
- [x] Spike file removed or kept under `vocab-photo-api/spike/` excluded from deploy
- [x] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Gate for T15. Nothing here ships.
