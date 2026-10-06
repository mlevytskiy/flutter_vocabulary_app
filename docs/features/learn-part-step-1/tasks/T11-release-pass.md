---
id: T11
title: "Deploy the Worker and run the release checks on device and in the browser"
layer: "tests"
deps: ["T10"]
acs: ["AC-08", "AC-11", "AC-11b", "AC-12"]
files_hint: ["docs/features/learn-part-step-1/tasks/T11-release-pass.md"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T11 — Deploy the Worker and run the release checks on device and in the browser

## Why

[spec §6](../spec.md) NFR table (every "at release" measurement); [sad §10](../sad.md) QG-1…QG-3; [sad §7](../sad.md) deployment (either side can go first); [sad §11](../sad.md) `.actions` at 320 px risk.

## What

- `npm run deploy` in `vocab-photo-api/`.
- Run each check; append a `## Release results` table to this file.

## Definition of Done

**Done when:** After `wrangler deploy`, the release checks from spec §6 / sad §10 are run and recorded in this task file with pass/fail per row: app learn page ≤ 300 ms (5 runs), web learn page ≤ 1.5 s on a phone over 4G (5 loads), no sideways scroll at 320 px (learn page and the shared page's `.actions` row), the top bar on a device/emulator at 360 dp/100 % and 320 dp/100 %/130 %, and both learn pages compared by eye for 11/11 exercises.

- [ ] every row in the results table is filled with a measured value and pass/fail
- [ ] any fail is either fixed (new commit) or written up as an owner decision

## Notes

- Manual task — no automated test. The app build to the store is outside this task.
