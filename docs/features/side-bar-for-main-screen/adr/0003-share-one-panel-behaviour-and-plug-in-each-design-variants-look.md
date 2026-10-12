---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-13"
feature_size: "M"
ticket: "roadmap #23"
---

# 0003 — Share one panel behaviour and plug in each design variant's look

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design pass

## Context

The owner wants two or three working looks of the photo tab and panel, compared on a phone behind a temporary Settings switch, with the others removed before release (spec §1, US-06). All variants must pass AC-01 to AC-18. They may differ only in their look (including how highlighted word rows look), in how full-open browses the large photos, and in whether the tab hides while the word list scrolls (AC-19). After the pick, only one remains and the switch is gone (AC-20). The spec's default is three variants (spec §8).

## Decision drivers

- Every variant passes AC-01 to AC-18, the same way, so the comparison is about the look only (AC-19).
- Removing the losing variants and the switch must be clean (AC-20).
- The look is meant to be designed freely by models within the allowed differences (spec §1, the owner's words).

## Considered options

1. **One shared behaviour plus a pluggable look per variant** — one `PhotoPanel` owns all behaviour; each variant implements a small `PhotoPanelLook` interface in its own file.
2. **A full copy of the panel per variant** — each variant is a complete widget with its own gestures, stops and animations; only the photo list is shared.

## Decision outcome

**Chosen:** Option 1. AC-01 to AC-18 are built and tested once, and the tests run for every look, so the variants cannot drift apart in behaviour. The pick is a deletion of files, not a merge.

How it works:
- **The shared behaviour lives in `PhotoPanel` and its helpers:** gestures and their direction, the openness value and the stops, Back, selection and highlight state, the jump to a photo's rows, keyboard closing, the busy and session-change rules, the gesture exclusion (ADR-0002), preview loading, and the screen-reader labels and actions (AC-18).
- **`photo_panel/looks/photo_panel_look.dart` declares only what AC-19 lets a variant choose:**
  - the tab: its size, at most 200 dp tall (ADR-0002), and how it draws its mini previews and count;
  - the half-open column's width, and the small photo's frame and place;
  - the full-open view: the large photo's place, and how it browses (a pager or a scrolling list, spec §8);
  - the expand and close controls' look;
  - the highlighted row's decoration, passed to `WordRowItem`;
  - whether the tab hides while the list scrolls.
- The looks live in `looks/look_a.dart`, `look_b.dart` and `look_c.dart`. The choice is `PhotoPanelVariant { a, b, c }`, kept by `photoPanelVariantProvider` in `lib/core/providers.dart` (`shared_preferences` key `photo_panel_variant`). The panel reads it, and the temporary "Photo panel design" choice in Settings writes it. A change applies at once (AC-19).
- **At the pick (AC-20)**, one task removes the losing looks, the enum, the provider, the stored key and the Settings choice. The kept look becomes the panel's only look, and the tests run on it alone.

## Consequences

**Positive**
- One implementation and one test suite for AC-01 to AC-18, run once per look.
- Fair comparison: the variants differ exactly where AC-19 allows and nowhere else.
- The pick is mechanical, and the `photo_panel_variant` grep must come back empty afterwards.

**Negative**
- A look can only change what the interface exposes. A design idea outside it (for example, a different stop) is a spec change, not a look.
- The interface must be fixed before the looks are drawn, so the first task builds the behaviour with one look, and the other looks follow.

**Neutral**
- After the pick, the interface could be folded into the single kept look. Leaving it costs one small file.

## Links

- Spec: [[../spec.md]] US-06, AC-19, AC-20, §8
- SAD: [[../sad.md]] §4, §5
- Related ADR: [[0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value]], [[0002-exclude-the-photo-tab-from-the-android-back-gesture-through-a-platform-channel]]
