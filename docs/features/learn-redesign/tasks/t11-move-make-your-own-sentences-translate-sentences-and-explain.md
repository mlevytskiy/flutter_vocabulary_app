---
id: T11
layer: app
deps: ["T7"]
acs: ["AC-08", "AC-10", "AC-15"]
estimate: L
owner: "implementer agent"
status: todo
---

# T11 — Move Make your own sentences, Translate sentences and Explain it to a friend into page sources and page bodies

**Derives from:** [spec](../spec.md) AC-08, AC-10, AC-15 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

existing tests stay green; new tests: one page per word, the sentence check reports via done(); Explain it to a friend uses its typed mode with no mode prompt; session pages write no exam word result while the old screens still do

## Files

- `lib/features/learn/own_sentences/`
- `lib/features/learn/translate_sentences/`
- `lib/features/learn/explain_to_friend/`
- `lib/features/learn/kit/sentence_check.dart`
- `test/learn_session_pages_sentences_test.dart`
