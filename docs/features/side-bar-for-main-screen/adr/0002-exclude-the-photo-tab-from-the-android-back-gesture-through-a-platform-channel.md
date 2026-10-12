---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-13"
feature_size: "M"
ticket: "roadmap #23"
---

# 0002 — Exclude the photo tab from the Android Back gesture through a platform channel

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design pass

## Context

On Android phones with gesture navigation, an inward swipe from the right edge of the screen means Back, and with the panel closed that would send the app to the background. The photo tab sits on the right side and opens with a drag to the left (AC-03), so a drag that starts on it must stay in the app. A swipe in from the edge that does not start on the tab must still work as Back (AC-12). Research for the spec named this the sharpest failure (spec §1). Flutter has no Dart API for Android's gesture exclusion, and the app has no native code yet (sad.md §2).

## Decision drivers

- 0 Back or page changes out of 20 drags started on the tab (spec §6 "Gesture safety"; KPI "Gesture misfires").
- A swipe from the right edge that does not start on the tab still works as Back (AC-12).
- No new package (CLAUDE.md rule 5). A platform channel in the app's own `MainActivity` is not a package.
- The design variants should be free to draw the tab against the screen edge (spec §1, AC-19).

## Considered options

1. **Keep the tab's touch area out of the system strip** — the tab's touch area starts left of `MediaQuery.systemGestureInsets.right`, so with gesture navigation the tab stands ~24–32 dp off the edge. Pure Dart.
2. **Exclude the tab's area through a platform channel** — the tab may touch the edge, and the app tells Android, through a `MethodChannel` handled in `MainActivity`, to exclude the tab's rectangle from the Back gesture (`View.setSystemGestureExclusionRects`, Android 10 and later).
3. **Both** — keep the touch area out of the strip and also exclude it natively.

## Decision outcome

**Chosen:** Option 2, a platform channel (owner's choice, 2026-10-13). The tab can sit against the right edge in every design variant. Android leaves only the tab's rectangle to the app, so a drag started on it opens the panel, and every other inward edge swipe is still Back (AC-12).

How it works:
- `lib/core/services/system_gesture_exclusion.dart` is a small service behind `systemGestureExclusionProvider` in `lib/core/providers.dart`. `setRects(List<Rect>)` takes logical rectangles in screen coordinates, converts them to physical pixels, and calls `MethodChannel('vocab/system_gesture_exclusion')`. It never throws: on iOS, on Android before 10, and in tests without a handler, it does nothing.
- `MainActivity` registers the channel in `configureFlutterEngine` and sets `window.decorView.systemGestureExclusionRects` on Android 10 and later.
- `PhotoPanel` sends the tab's rectangle when the tab is shown and the panel is closed. It sends it again after the tab is moved, after a layout change (keyboard, rotation, safe area) and when the photo list changes the tab's size. It sends the panel's handle rectangle while half-open, so the drag to full-open stays in the app too. It sends an empty list whenever no tab is shown: no photo with words, the drawer open, full-open, or another route on top. The tab is shown on every page of the pager, so its rectangle stays excluded on the dialogue pages too.
- Every look's tab is at most 200 dp tall, because Android honours at most 200 dp of excluded height per edge. The look interface checks this (ADR-0003).
- While the panel is half-open or full-open, a system Back that is not excluded reaches the main screen's `PopScope` and steps the panel back one stop (AC-10). So even an unexcluded swipe never sends the app to the background while the panel is open.

## Consequences

**Positive**
- The tab can touch the edge, which is the owner's picture of "something I can drag" on the right side (spec §1).
- Only the tab's own area is taken from the system; Back from the rest of the right edge is unchanged (AC-12).

**Negative**
- The app's first native code: a Kotlin channel handler in `MainActivity`, which must be kept working through Flutter upgrades.
- The excluded rectangle must follow the tab exactly. A stale rectangle would either leave the tab unprotected or block Back where no tab is shown. The send points above are each a widget test against a mocked channel.
- Whether Android honours the exclusion can only be seen on a real phone. The 0-of-20 check is a device pass on an Android phone with gesture navigation (spec §6).

**Neutral**
- iOS needs nothing: its back swipe is from the left edge, and the main screen is the root route.
- If the exclusion proves unreliable on some phone, option 1 can be added later as a Dart-only inset, without removing the channel.

## Links

- Spec: [[../spec.md]] AC-03, AC-12, §6 "Gesture safety", §7 "Gesture misfires"
- SAD: [[../sad.md]] §4
- Related ADR: [[0001-draw-the-photo-tab-and-panel-in-an-overlay-above-the-pager-driven-by-one-openness-value]], [[0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look]]
