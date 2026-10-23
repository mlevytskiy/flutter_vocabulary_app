---
id: T8
layer: app
deps: ["T7"]
acs: ["AC-08", "AC-10", "AC-15"]
estimate: L
owner: "implementer agent"
status: todo
---

# T8 — Move Pick the right answer, Remember or not and Quiz into page sources and page bodies shared with their screens

**Derives from:** [spec](../spec.md) AC-08, AC-10, AC-15 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

existing tests of the three exercises stay green; new tests: each page source yields one page per usable word with the right step; Remember or not 'I didn't' reports a miss via done(); session pages never call the exam result sink

## Files

- `lib/features/learn/pick_the_answer/`
- `lib/features/learn/remember_or_not/`
- `lib/features/learn/quiz/`
- `test/learn_session_pages_basic_test.dart`
