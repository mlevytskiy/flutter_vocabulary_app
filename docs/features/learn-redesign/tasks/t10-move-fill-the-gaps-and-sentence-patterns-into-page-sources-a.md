---
id: T10
layer: app
deps: ["T7"]
acs: ["AC-08", "AC-10", "AC-11"]
estimate: M
owner: "implementer agent"
status: todo
---

# T10 — Move Fill the gaps and Sentence patterns into page sources and page bodies

**Derives from:** [spec](../spec.md) AC-08, AC-10, AC-11 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

existing tests stay green; new tests: one gap page per word with Check via ready(); data failure → no page; step 2

## Files

- `lib/features/learn/fill_the_gaps/`
- `lib/features/learn/sentence_patterns/`
- `test/learn_session/pages_gaps_test.dart`
