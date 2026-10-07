---
id: T20
title: "Update the repo docs this design outdates and run the release checks"
layer: "docs"
deps: ["T9", "T16", "T17", "T19"]
acs: ["AC-06", "AC-07", "AC-18"]
files_hint: ["CLAUDE.md", "docs/architecture.md", "vocab-photo-api/README.md", "docs/features/learn-part-step-1/CONTEXT.md", "docs/features/mnemonic-story/CONTEXT.md", "docs/roadmap.md"]
owner: "Maksym"
estimate: "M"
status: "in-progress"
---

# T20 — Update the repo docs this design outdates and run the release checks

## Why

[sad §11](../sad.md) "Repo texts this design outdates" and the Security review row; [spec §6](../spec.md) measurements done at release.

## What

- CLAUDE.md rule 3 (the new visible parts) and rule 5 (`WordGroup`, `StoryRun`, `StoryStep`, `WordPair.rowId` approved). architecture.md §1/§3 (`core/story/`, new features, routes, stores). The README (deploy order from sad §7). learn-part-step-1 CONTEXT ("the learn page saves nothing" narrowed). The glossary terms "offered AI list" and "grouped-words key". Roadmap status.
- Release checks on the owner's phone: grouping ≤ 30 s for 60 words (5 runs), saved story ≤ 500 ms (5 runs), 4× zoom with no blur at 2×, ≤ 3 MB per run after 10 runs, and a live run against real providers on a staging deploy. Security review sign-off.

## Definition of Done

**Done when:** The listed docs describe the shipped design, and the release-check results (grouping time, saved-open time, zoom, storage, staging run, security sign-off) are recorded in this task file's Notes.

- [x] CLAUDE.md, architecture.md and README updated (README deploy checklist was added by T9; not duplicated)
- [ ] release measurements recorded
- [ ] Security Lead sign-off recorded

## Notes

- Owner deployed on 2026-10-07: remote migration 0004 applied, secrets XAI_API_KEY / HIGGSFIELD_API_KEY / OPENCODE_ZEN_API_KEY set, `wrangler deploy` version 7e83d809-d3c5-4639-9f81-dc4d9f5fb2c5. A live grouping bug was found right after: with 45 words Haiku answered 10 groups of 2 to 6 words with invented ids on new groups, the Worker passed it on (200) and the app's `applySplit` rejected it ("Could not group your words"). Fixed in the Worker only (commit "make the grouping split always valid for the app"): prompt states the word count and target number of groups, the Worker validates with the app's rules, retries the AI once, then repairs deterministically. **Needs a redeploy** (`npm run deploy` from `vocab-photo-api/`); no app build needed.
- The story run time (≤ 3 min median of the first 10 runs) and the ±25 % price check happen after release, on the story runs screen.

### Docs done (2026-10-07)

CLAUDE.md rules 3 and 5; architecture.md §1 (core/story, stores, services, new feature folders), §3 (diagram + "Mnemonic story" section); learn-part-step-1 CONTEXT (the app's learn page now keeps word groups and the selected group; "mnemonic story" entry points to the new feature); mnemonic-story CONTEXT (new terms "offered AI list", "grouped-words key"); roadmap step 21 (in progress). As shipped: non-Anthropic models in `models.json` are `provisional`; pickers list cheapest first with a list-price line (owner request, in spec AC-12); xAI, Higgsfield and OpenCode Zen keys are Worker secrets.

### Release checks — pending owner

Needs the owner's phone, a staging deploy and a security sign-off. None was done by the agent.

Measurements (record the result next to each):

- [ ] Grouping 60 words takes <= 30 s (5 runs): ______
- [ ] A saved story opens in <= 500 ms (5 runs): ______
- [ ] 4x zoom on the picture, no blur at 2x: ______
- [ ] <= 3 MB per run on the phone after 10 runs: ______
- [ ] Live run against the real providers on a staging deploy (story, picture prompt, picture, check prices against the provider dashboards): ______
- [ ] Verify the `provisional` entries in `vocab-photo-api/src/story/models.json` (OpenCode Zen ids/prices, xAI `grok-imagine-image` $0.02, Higgsfield `marketing-studio/image/sunburst` ~$0.013) and drop the flag
- [ ] Security Lead sign-off (every story route behind `x-app-secret` + rate limit; no story route public; 20 runs/UTC day cap; keys only as Worker secrets): ______

Deploy steps for the owner to approve (run from `vocab-photo-api/`; order D1 -> Worker -> app build; confirm R2 is enabled and `SOURCES` is bound first):

```
npx wrangler secret put XAI_API_KEY
npx wrangler secret put HIGGSFIELD_API_KEY      # "<key_id>:<key_secret>"
npx wrangler secret put OPENCODE_ZEN_API_KEY
npx wrangler d1 migrations apply DB --remote    # applies 0004_story_runs
npx wrangler d1 migrations list DB --remote     # -> "No migrations to apply!"
npm test && npm run typecheck && npm run deploy # creates the STORY_RUN Workflow
```

Then release the app build. A provider without a secret should be removed from `models.json` before deploying (the app shows only the fetched list).
