---
id: T2
title: "Add a node:test harness that runs against wrangler dev"
layer: "tests"
deps: []
acs: ["AC-32"]
files_hint: ["vocab-photo-api/package.json", "vocab-photo-api/test/", "vocab-photo-api/scripts/test.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T2 — Add a node:test harness that runs against wrangler dev

## Why

[sad §10](../../../features/good-looking-web/sad.md) — Worker verification harness (inline decision: `node --test`, no new package). Acceptance criteria: [AC-32](../../../features/good-looking-web/spec.md).

## What

`npm test` starts `wrangler dev` on a free port with local bindings, waits for it, runs `node --test test/`, then stops it. Shared helpers: base URL, `appHeaders()` with the dev secret from `.dev.vars`, a `publish()` helper. First test: `GET /s/<random uuid>` answers the "gone" page (AC-32).

## Definition of Done

- [ ] `npm test` passes locally from a clean checkout (after `npm install`)
- [ ] The smoke test proves an unknown id gets the gone page
- [ ] `npm run typecheck` clean; no new dependency in package.json
- [ ] `flutter analyze` / `npm run typecheck` add no new issue; the `CLAUDE.md` greps stay clean

## Notes

Every later Worker task adds its RED test here first.
