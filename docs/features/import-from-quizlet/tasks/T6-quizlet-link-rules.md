---
id: T6
title: "Find a Quizlet set link in pasted text and decide which navigations the web view may follow"
layer: "domain"
deps: []
acs: ["AC-02", "AC-06", "AC-11", "AC-13"]
files_hint: ["lib/core/services/quizlet_link.dart", "test/quizlet_link_test.dart"]
owner: "Maksym"
estimate: "S"
status: "todo"
---

# T6 — Find a Quizlet set link in pasted text and decide which navigations the web view may follow

## Why

spec AC-02, AC-06, AC-11, AC-13; [sad §4](../sad.md) link parsing; [ADR-0004](../adr/0004-allow-only-quizlet-pages-of-the-pasted-set-in-the-web-view.md).

## What

- Pure Dart: link finder → `QuizletSetLink(setId, plainUrl)`; navigation predicate; a shared `setIdOf(uri)`.
- Test table of link shapes, reused as Worker cases in T2.

## Definition of Done

**Done when:** `QuizletLink.find(text)` returns the set id and plain link for every link shape in AC-02 (bare, with/without `https://` and `www.`, language part, sharing extras, study-mode path, inside Quizlet's share text) and null for another site, a folder or class link or plain words; `isNavigationAllowed(uri, setId)` allows only https quizlet.com pages of that set (and non-set Quizlet pages such as the robot check) and refuses other hosts, other schemes and other set ids; table-driven unit tests pass.

- [ ] unit tests pass
- [ ] `flutter analyze` clean

## Notes

- Include the owner's example `https://quizlet.com/ar/987534268/job-interview-flash-cards/?i=xxug6&x=1jqt` → `https://quizlet.com/987534268/job-interview-flash-cards/`.
