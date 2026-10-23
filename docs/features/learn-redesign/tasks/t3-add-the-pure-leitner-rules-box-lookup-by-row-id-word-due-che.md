---
id: T3
layer: domain
deps: ["T2"]
acs: ["AC-12", "AC-13", "AC-15", "AC-22"]
estimate: M
owner: "implementer agent"
status: todo
---

# T3 — Add the pure Leitner rules: box lookup by row id + word, due check, applySession, intervals

**Derives from:** [spec](../spec.md) AC-12, AC-13, AC-15, AC-22 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

unit tests: clean word up one box (new→1, 5 stays 5), any miss → box 1, up at most once per calendar day, intervals 1/2/4/8/16, word edit → new, deleted row pruned, talk unused → unchanged, result states known/shaky/new/unused

## Files

- `lib/features/learn/session/leitner.dart`
- `test/learn_session/leitner_test.dart`
