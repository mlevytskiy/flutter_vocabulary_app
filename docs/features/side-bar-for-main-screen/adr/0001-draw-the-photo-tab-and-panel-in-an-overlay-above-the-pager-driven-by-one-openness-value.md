---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-13"
feature_size: "M"
ticket: "roadmap #23"
---

# 0001 — Draw the photo tab and panel in an overlay above the pager, driven by one openness value

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design pass

## Context

The photo panel has three stops (closed, half-open, full-open) and moves between them under the finger: a drag released between stops settles at the nearest one, a flick goes one further, and the small photos visibly grow into the large ones on the way (AC-07, AC-08). In half-open the word list beside the panel must still scroll (AC-06), and Back must walk the panel back one stop at a time without leaving the main screen (AC-10). The words page will be page 1 of the main screen pager from get-words-from-subtitles-improvment (T19), and dragging the tab must not change the page (AC-13). The main screen's body today is a `Stack` of the word list and the "Analyzing photo..." overlay (sad.md §2).

## Decision drivers

- Smooth, continuous drags and settles: ≤ 5 % dropped frames; half-open fully settled ≤ 300 ms after the tap (spec §6).
- A drag on the tab must never change the page (AC-13; spec §6 "Gesture safety").
- The list stays scrollable in half-open (AC-06), and Back steps back one stop (AC-10).
- No new package (CLAUDE.md rule 5); no new route (the panel is not a page, ux-flows "Platform decisions").

## Considered options

1. **An `OverlayPortal` above the whole pager, driven by one openness value** — the tab and panel are one widget whose overlay child is painted in the Navigator's overlay just above the main screen's route, and their whole state is one 0→1 value with a stop at half-open; shown only while the words page is the current page.
2. **One overlay inside the words page's `Stack`, driven by one openness value** — the same single value, but the tab and panel are a child of the words page's `Stack`, so they move with the page and sit under the AppBar.
3. **Half-open in the page, full-open as a dialog** — half-open is a column in the words page's `Stack`; full-open is a full-screen dialog like the words table's `PhotoViewer`, reached with a `Hero` transition. A real alternative here: a dialog is not a route in this repo (architecture.md §2 rule 1), and with `PopScope` Back would still stay on the main screen, so ux-flows' "the panel is not a new page" does not rule it out.

## Decision outcome

**Chosen:** Option 1, the overlay above the pager (owner's choice, 2026-10-13). Because the overlay child is hit-tested before the main screen's route, a touch that starts on the tab never reaches the `PageView` or the word rows, so AC-13 and AC-14 hold without any gesture contest. Full-open can cover the whole screen, AppBar included. One openness value in one `AnimationController` keeps drag, settle and the small-to-large growth continuous, which option 3 cannot do across the dialog boundary.

How it works:
- `PhotoPanel` (in `lib/features/word_input/photo_panel/`) is mounted by the main screen and owns an `OverlayPortal`. The screen's `State` owns a `PhotoPanelController` (the current stop, the selected photo) and reads it for Back, for the rows' touch rule and for the pager's physics.
- The openness value runs from 0 (closed) through 0.5 (half-open) to 1 (full-open). A horizontal drag moves it directly, and on release a pure rule (`photo_panel_stops.dart`) picks the stop from the position and the velocity (AC-08). Each photo's rectangle is interpolated between its small place in the column and its large place in full-open, so the photos grow on the way (AC-07).
- In half-open, only the panel itself is hit-testable. Touches beside it reach the main screen, so the list scrolls (AC-06). The screen wraps row content in `IgnorePointer` and closes the panel on a tap on the list (AC-11). It also sets `NeverScrollableScrollPhysics` on the pager while the panel is open (AC-13).
- When the pager exists, the tab stays at its place on every page and does not move with a swipe. Opening the panel from a dialogue page first returns the pager to the words page, then opens it there (owner decision at the critic pass, 2026-10-13; sad.md §1 Decision override, which amends AC-13).
- Because the overlay paints above everything inside the main screen's route, the panel also handles the things a `Stack` child would get for free:
  - The tab and panel are hidden while the drawer is open, and the panel closes when the drawer opens.
  - The tab ignores touches while `_isAnalyzingPhoto` (AC-17).
  - The tab's lowest position keeps clear of the floating-button row and a SnackBar.
  - The panel closes before the screen pushes another route.
  - Dialogs and pushed routes are separate overlay entries and still cover it.
- `PopScope` on the main screen lets Back leave only while the panel is closed; otherwise Back steps back one stop (AC-10).

## Consequences

**Positive**
- A drag or tap on the tab never competes with the pager or the rows, so AC-13 and AC-14 hold by construction, and a widget test can show it.
- Full-open can use the whole screen to show the photographed page.
- One value drives the drag, the settle and the growth animation, so there is one place to tune smoothness.

**Negative**
- The overlay is above the main screen's own drawer, SnackBar and "Analyzing photo..." overlay, so the panel must hide, clamp or ignore touches for each of them explicitly. Each is a widget test, and a missed case would show the tab over the open drawer or let it open while busy.
- On a dialogue page the tab covers the right edge of the dialogue text, and opening the panel there first animates the pager back to the words page.
- Back and screen-reader actions are written by hand (`PopScope`, `Semantics`), not inherited from a route.

**Neutral**
- Moving the panel into the words page's `Stack` (option 2) later would keep the openness model and most of the code. Mostly the mounting and the hit-test rules would change.

## Links

- Spec: [[../spec.md]] AC-06, AC-07, AC-08, AC-10, AC-11, AC-13, AC-14, AC-17
- SAD: [[../sad.md]] §4
- Related ADR: [[0002-exclude-the-photo-tab-from-the-android-back-gesture-through-a-platform-channel]], [[0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look]]
