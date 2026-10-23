---
id: T5
layer: domain
deps: []
acs: ["AC-08", "AC-09"]
estimate: M
owner: "implementer agent"
status: todo
---

# T5 — Add the pure ladder queue: rungs, miss down-one and reinsert 3 later, due words first, done when all passed Use

**Derives from:** [spec](../spec.md) AC-08, AC-09 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

unit tests with seeded Random: clean word takes 3 rights; miss on Practise → Meet, back 3 pages later or at end; never the same word next while others remain; miss on Meet stays Meet; per-word miss flag; due words' pages first

## Files

- `lib/features/learn/session/ladder_queue.dart`
- `test/learn_session_ladder_queue_test.dart`
