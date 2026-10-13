---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "S"
ticket: "learn-part-step-1"
---

# 0003 — Keep the exercise list as JSON in the Worker and test the app's copy against it

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The app's learn page and the web learn page must list the same eleven exercises, in the same three stages and order, with the same available / coming-soon state (CONTEXT invariant; spec §6 "Same plan on app and web": 11 of 11, plus a test that compares both lists). Every later learning step ships an exercise by switching it on in this list. An exercise's id will appear in the web links of ADR-0002 (`/s/:id/learn/mnemonic-story`, `?pick=`) and will later key learning progress, so it is costly to rename. The app has no network dependency on the Worker for anything but publishing, and CLAUDE.md rule 5 forbids a new domain model without asking.

## Decision drivers

- sad §1 quality goal 1 / spec §6: 11 of 11 match, checked by a test.
- Spec §6: ≤ 300 ms from tapping Learn to the app's learn page, so the list must be on the device.
- The repo's "two implementations, one shape" precedent: `anki_export.dart` and the Worker's download are both tested against the format in `vocab-photo-api/README.md`.

## Considered options

1. **JSON in the Worker as the source, a Dart copy in the app, and a Flutter test that compares them.** `vocab-photo-api/src/learn/exercises.json` is imported by the Worker at build. `lib/features/learn/exercises.dart` holds a `const` list of `Exercise`. A Flutter test reads the JSON file and compares it entry by entry.
2. **A separate reference file that both sides are tested against**, as with the AnkiDroid format. This makes three copies of the list (reference, TypeScript, Dart) and two tests.
3. **The app fetches the list from the Worker** when the learn page opens. That gives one copy, but no learn page offline, a network round trip inside the 300 ms, and loading and error states the spec does not have.

## Decision outcome

**Chosen:** Option 1. It keeps the app offline and fast, and it leaves only two copies with one check that fails `flutter test` on any difference. The shape is fixed now:

- Each entry is `{ "id": string, "name": string, "stage": 1 | 2 | 3, "available": boolean }`, and array order is plan order.
- The ids, all stable kebab-case, are: `mnemonic-story`, `match-synonyms`, `match-antonyms`, `match-definitions` (stage 1); `pick-the-answer`, `fill-the-gaps`, `remember-or-not` (stage 2); `own-sentences`, `translate-sentences`, `own-sentences-spoken`, `translate-sentences-spoken` (stage 3).
- Only `mnemonic-story` is `available: true`. The names are the spec's AC-04 labels, verbatim.
- **Override of CLAUDE.md rule 5:** the owner approved the one new type `Exercise` (id, name, stage, available) on 2026-10-06. It lives in the learn feature folder, not in `lib/core/models/`, because only the learn feature reads it.

## Consequences

**Positive**
- A mismatch between app and web fails a test, not a release check.
- The app's learn page needs no network, and the web learn page needs no data beyond the session.

**Negative**
- Switching an exercise on means editing two files in one change, with the test enforcing it.
- The Worker deploys immediately, but the app reaches the phone only with a store build. In between, the web can show an exercise as available while an older app still shows it as coming soon.

**Neutral**
- Renaming an id later breaks old `?pick=` links (harmlessly: an unknown pick is ignored) and would need a mapping once progress is stored.

## Links

- Spec: [[../spec.md]] AC-04, AC-06; §6 "Same plan on app and web"
- SAD: [[../sad.md]] §4
- Related ADR: [[0002-render-the-web-learn-page-on-the-worker-and-keep-ticks-in-its-link]]
