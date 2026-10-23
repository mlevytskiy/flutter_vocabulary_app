---
id: T9
layer: app
deps: ["T7"]
acs: ["AC-08", "AC-10", "AC-11"]
estimate: L
owner: "implementer agent"
status: todo
---

# T9 — Move Match synonyms, Match word and definition and Guess my word into page sources and page bodies

**Derives from:** [spec](../spec.md) AC-08, AC-10, AC-11 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

existing tests stay green; new tests: boards make one page per 4 words (last board 3–4) reporting per-word results via done(); Guess my word one page per word; a data failure yields no page and an error, never a half page

## Files

- `lib/features/learn/match_synonyms/`
- `lib/features/learn/match_definitions/`
- `lib/features/learn/guess_my_word/`
- `lib/features/learn/kit/match_board.dart`
- `test/learn_session/pages_match_test.dart`
