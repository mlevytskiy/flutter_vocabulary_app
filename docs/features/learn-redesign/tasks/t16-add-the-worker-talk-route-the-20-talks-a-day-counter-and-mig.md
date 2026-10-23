---
id: T16
layer: ports
deps: []
acs: ["AC-23", "AC-24"]
estimate: M
owner: "implementer agent"
status: todo
---

# T16 — Add the Worker talk route, the 20-talks-a-day counter and migration 0008

**Derives from:** [spec](../spec.md) AC-23, AC-24 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

Worker tests: start takes a unit and the 21st start in a UTC day is refused with the day-limit code; replies never take a unit and are refused past 24 history messages; refuses without the app secret; prompt includes scene, words and target and returns reply + next target; typecheck green

## Files

- `vocab-photo-api/src/learn/talk.ts`
- `vocab-photo-api/src/learn/routes.ts`
- `vocab-photo-api/src/learn/allowance.ts`
- `vocab-photo-api/migrations/0008_talk_allowance.sql`
- `vocab-photo-api/test/learn_talk.test.ts`
