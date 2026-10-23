---
id: T6
layer: wiring
deps: ["T1"]
acs: ["AC-05", "AC-17", "AC-18"]
estimate: S
owner: "implementer agent"
status: todo
---

# T6 — Add learn preferences: presets, enabled exercises, words per session, split per collection, last played group

**Derives from:** [spec](../spec.md) AC-05, AC-17, AC-18 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

provider tests with mocked SharedPreferences: Balanced default with its 10 exercises, Quick/Deep contents per spec AC-17, switch change → Custom, last switch of a step refused, split default true per collection, words per session default All

## Files

- `lib/core/providers.dart`
- `lib/features/learn/entry/learn_presets.dart`
- `test/learn_session/learn_prefs_test.dart`
