---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "M"
ticket: "import-from-quizlet"
---

# 0003 — Read the page data with a thin script and parse it in Dart

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

A Quizlet set page carries its cards twice: as the visible list of terms and as the embedded data the page renders itself from (which usually holds every card even when only part is on screen). Quizlet can change either at any time, and reading the set whole — or naming the gap — is the feature's first quality goal (AC-08, spec §6 "100% of the set's cards for sets of up to 500 cards"). The reading code must be fixable fast when Quizlet changes, and testable without a phone.

## Decision drivers

- sad §1 quality goal 1: whole set, set order, up to 500 cards; the page's stated card count read for "Read X of Y".
- spec §1: read from the page itself, on the phone, no server step, no AI.
- Testability with the existing toolchain (`flutter test`), no new package (CLAUDE.md rule 5).
- spec §8 OQ-1: stay as close as possible to "reading the page the learner sees".

## Considered options

1. **Thin script + parsing in Dart** — a short script (an asset file) returns raw material: the page's embedded data as text, else the visible term list's text, plus the set's name, its id as the page states it and the "Terms in this set (N)" count; Dart finds the cards, checks the set id and cleans the text.
2. **All parsing in a script on the page** — the script returns finished `{term, back, example}` cards.
3. **Quizlet's internal JSON API from the page** — the script fetches Quizlet's unpublished card API page by page with the cookies that passed the robot check.

## Decision outcome

**Chosen:** Option 1. The part that breaks when Quizlet changes is the parsing, and in Dart it is unit-tested against fixtures saved from real set pages; a layout change means "save a new fixture, fix the parser". Embedded data is preferred because it holds every card; the visible list is the fallback. Option 2 puts the fragile logic where it cannot be tested without a device. Option 3 stops being "reading the page" (spec §1), raises the terms-of-use risk of OQ-1 and depends on an unpublished API.

## Consequences

**Positive**
- `quizlet_set_parser` is a pure function: raw page material → set (name, stated count, cards in order) or "not understood"; covered by `flutter test` with fixtures of sets of several sizes, with examples, with image-only cards.
- The script stays ~20 lines and rarely changes.

**Negative**
- For a 500-card set some hundreds of KB of raw text cross the script→Dart bridge once per read attempt (acceptable; the reader stops polling as soon as cards are found).
- Fixtures must be refreshed when Quizlet changes its page; a change that nobody notices shows as AC-07 failures or "Read X of Y" lines (sad §11).

**Neutral**
- If the embedded data and the visible list ever disagree, the embedded data wins; the stated count still drives "Read X of Y".

## Links

- Spec: [[../spec.md]] AC-02, AC-08, AC-09, §6 "Cards found"
- SAD: [[../sad.md]] §4, §5, §10 QG-1
- Related ADR: [[0002-show-the-set-page-with-webview-flutter]]
