---
id: T3
title: "Add the word check every story must pass to the Worker"
layer: "domain"
deps: []
acs: ["AC-08"]
files_hint: ["vocab-photo-api/src/story/word-check.ts", "vocab-photo-api/test/story-word-check.test.mjs"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T3 — Add the word check every story must pass to the Worker

## Why

[spec AC-08](../spec.md) word rule; [sad §4](../sad.md) "Word check"; CONTEXT invariant "A mnemonic story shows every word of its group as written".

## What

- `missedWords(story, words) → string[]`. A word counts when it appears as a whole word in any case. A phrase counts when its words appear in order, next to each other. Each English word may take -s, -es, -ed or -ing. A word inside another word does not count.

## Definition of Done

**Done when:** `missedWords` returns exactly the group words the story does not contain under AC-08's rule, and `story-word-check.test.mjs` covers case, phrases, the four endings, "veers off" for "veer off", "live" inside "deliver", and the owner's sample story.

- [ ] all AC-08 examples pass
- [ ] `npm test` and `npm run typecheck` pass in `vocab-photo-api/`

## Notes

- Pure function, so it can start on day one beside T1 and T2.
