---
id: T6
title: "Verify the whole switch on the device and update the docs"
layer: "docs"
deps: ["T3", "T4", "T5"]
acs: ["AC-05", "AC-07", "AC-10"]
files_hint: ["docs/architecture.md", "docs/roadmap.md", "docs/features/edit-session-from-history/tasks/"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T6 — Verify the whole switch on the device and update the docs

## Why

Covers the ACs that need the real app and the shared page — [spec AC-05, AC-07, AC-10](../spec.md) — and the [spec §6 NFR](../spec.md) / [sad §10](../sad.md) checks.

## What

Device pass (release build), then docs:
1. Type a word and switch within half a second → both sessions correct in History (AC-07).
2. Share session A, open its page on another device, switch to A and edit → page unchanged; share again → same link updated after the existing warning (AC-10).
3. The shared page offers no way to make a session current (AC-05).
4. Before/after screenshots of History, words screen and main screen → 0 differing areas outside the new button and question.
5. Yes → main screen with ≤100 words in ≤ 1 s.
6. `docs/architecture.md` (§1 notifier/store lines) and `docs/roadmap.md` (a step row for this feature) updated.

## Definition of Done

- [ ] All six checklist items ticked in this file with the date.
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test` and the `CLAUDE.md` greps are clean.

## Notes

Needs the owner's phone; not automatable.
