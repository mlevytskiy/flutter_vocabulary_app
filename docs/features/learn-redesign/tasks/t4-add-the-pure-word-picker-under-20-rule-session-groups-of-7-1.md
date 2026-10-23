---
id: T4
layer: domain
deps: ["T3"]
acs: ["AC-05", "AC-06", "AC-07", "AC-14"]
estimate: M
owner: "implementer agent"
status: todo
---

# T4 — Add the pure word picker: under-20 rule, session groups of 7–12 in AI-group order, due/new/after-last choice, words-per-session cap, explicit row ids

**Derives from:** [spec](../spec.md) AC-05, AC-06, AC-07, AC-14 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

unit tests: 15 words → all; 34 words split → groups 7–12 covering every word incl. waiting words and row-order fallback; first group with due, else new, else after last; Next group skips the played one; split off with cap 10/20/30/All due-new-others; rowIds wins; label 'Group 2 of 4 · 9 words'

## Files

- `lib/features/learn/session/session_words.dart`
- `test/learn_session/session_words_test.dart`
