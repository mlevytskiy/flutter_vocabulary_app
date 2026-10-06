---
id: T2
title: "Accept, store and load set sources in the Worker publish path"
layer: "ports"
deps: ["T1"]
acs: ["AC-12", "AC-13", "AC-13b"]
files_hint: ["vocab-photo-api/src/session/types.ts", "vocab-photo-api/src/session/handlers.ts", "vocab-photo-api/src/session/store.ts", "vocab-photo-api/test/publish.test.mjs", "vocab-photo-api/test/limits.test.mjs", "vocab-photo-api/test/helpers.mjs"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T2 — Accept, store and load set sources in the Worker publish path

## Why

[ADR-0006](../adr/0006-publish-set-sources-in-the-sources-list-with-a-kind.md), [sad §6 F4](../sad.md), [sad §8](../sad.md) error handling, [data-model.md](../data-model.md) `sources`, spec §6.1 "only accepts a Quizlet set link".

## What

- `types.ts`: `SetSource { kind: "set", id, name, url }` joins the `SessionSource` union; `DeclaredSource` gets an optional `kind` (missing = photo) plus `name`/`url` for a set; `StoredSource` gains `kind`, `name`, `url`; `toDocument` lists arrived sets; remove `MAX_SOURCES`; a `isPlainQuizletSetUrl` check (`https://quizlet.com/<digits>/<slug>/`, no query or fragment).
- `handlers.ts`: publish refuses an invalid set with `{error, code: "invalid_source"}`.
- `store.ts`: insert set slots `arrived` at the publish revision with name and url; select `kind, name, url`; `storeDeclaredPhoto` and `getSourceObject` require `kind = 'photo'`.
- Tests: the 12-photos-and-3-sets publish keeps all 15 in order; the invalid-set cases; an older payload without `kind` still publishes photos; upload to a set id answers not declared.

## Definition of Done

**Done when:** A publish with photos and sets stores every source in order (sets arrived at once, photos pending), the session loads `kind`/`name`/`url`, a set with a non-Quizlet or query-bearing link or a name over 500 characters is refused with `invalid_source`, there is no 10-source cap, and bytes can be neither uploaded to nor served for a set slot; covered by `node --test`.

- [ ] `npm test` passes with the new publish, limit and upload cases
- [ ] `npm run typecheck` clean

## Notes

- Compile-coupled contract change folded in here (the `SessionSource` union is read by `page.ts`); keep `page.ts` compiling by treating a set as "not a photo" until T3 renders it.
- The link rule must accept exactly the plain link the app produces in T6 — use the same table of link shapes as test cases (sad §11).
