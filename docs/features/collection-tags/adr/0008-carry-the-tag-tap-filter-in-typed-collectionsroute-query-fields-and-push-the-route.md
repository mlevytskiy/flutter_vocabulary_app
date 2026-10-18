---
status: Accepted
owner: "Maksym (app owner), decided by the Fable 5.1 owner proxy"
reviewers: ["Tech Lead"]
updated_at: "2026-10-16"
feature_size: "L"
ticket: "roadmap #25 — collection-tags"
---

# 0008 — Carry the tag-tap filter in typed CollectionsRoute query fields and push the route

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Fable 5.1 owner proxy (delegated by the owner) with Claude during the design pass

## Context

Tapping a tag on the main screen opens the Collections screen filtered by that tag (text and kind). Back returns straight to the main screen (AC-14, AC-39). `CollectionsRoute` (`routes.dart:240-245`) takes no parameters today, and CLAUDE.md rule 1 allows only typed routes.

## Decision drivers

- Rule 1: typed routes only, and no string paths.
- Back must return to the main screen, and Back from a search started on Collections must clear it first (ux-flows states).

## Considered options

1. **Typed query fields** `tagKind` and `tag` (both nullable) on `CollectionsRoute`, opened with `.push(context)` from the tag line. The screen seeds its search notifier from them.
2. **Seed a provider, then push**: write the filter into the Collections search notifier, then `const CollectionsRoute().push(context)`.

## Decision outcome

**Chosen:** option 1. The filter is part of the route, so it survives a rebuild and is testable through the router, and `push` gives the required Back. Option 2 also gives the right Back, but it keeps navigation state in a provider. A stale filter could then show when Collections is next opened from the side menu, unless every other entry resets it.

## Consequences

**Positive**
- Deep-linkable and testable, and rule 1 is kept.

**Negative**
- `routes.g.dart` is regenerated, and the side menu's entry keeps using the parameterless form.

**Neutral**
- More filter fields could be added to the route later.

## Links

- Spec: [[../spec.md]] AC-14, AC-39
- SAD: [[../sad.md]] §4
