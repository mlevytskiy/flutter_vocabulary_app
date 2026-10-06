---
id: T7
title: "Write the reader script and parse raw set-page material into a set"
layer: "domain"
deps: ["T6"]
acs: ["AC-02", "AC-05", "AC-08", "AC-11"]
files_hint: ["lib/core/services/quizlet_page_script.dart", "lib/core/services/quizlet_set_parser.dart", "test/quizlet_set_parser_test.dart", "test/fixtures/quizlet/"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T7 — Write the reader script and parse raw set-page material into a set

## Why

[ADR-0003](../adr/0003-read-the-page-data-with-a-thin-script-and-parse-it-in-dart.md); spec AC-02, AC-05, AC-08, AC-11; [sad §4](../sad.md) waiting and robot check; [sad §10](../sad.md) QG-1.

## What

- The script (a Dart string constant) returns JSON: the page's embedded data as text if present, else the visible term list's text, plus title, the set id the page states, the "Terms in this set (N)" count and robot-check markers.
- The parser is pure Dart; robot-check markers live in one list.
- Fixtures: raw material saved from real set pages (the owner's example set and two others of different sizes) and from a robot-check page.

## Definition of Done

**Done when:** `quizlet_page_script.dart` holds the reader script; `parseQuizletPage(raw, setId)` returns the set (name, stated count, cards in set order with term, back and example), a robot check, or nothing-yet, and ignores material of another set id; tests over saved fixtures cover embedded data, the visible-list fallback, a set with examples, image-only cards and a robot-check page.

- [ ] parser tests pass on every fixture
- [ ] `flutter analyze` clean

## Notes

- **Owner input needed:** fixtures come from real Quizlet pages, which refuse plain automated reads. Capture them from a desktop browser that has passed the check (run the script in the console, save its output). If they are not available yet, write the parser against clearly marked synthetic fixtures and leave a note — T17 must then confirm on real sets.

## Result note (2026-10-06)

No real captured pages were available, so every fixture in `test/fixtures/quizlet/` is synthetic (see its `README.txt`), and the script's selectors and the embedded-data shape (`studiableItems` / `cardSides` / text media type 1; flat `terms` fallback) are unverified guesses. **T17 must run the script on real sets and a robot-check page, save the output as fixtures and fix script/parser to match.**
