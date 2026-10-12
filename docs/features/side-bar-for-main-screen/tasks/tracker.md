# Tracker — side-bar-for-main-screen

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Add the pure settle rule and the photo panel controller](./T1-domain-settle-rule-and-controller.md) | domain | Maksym | S | — | done |
| T2 | [Derive the current session's photos with words](./T2-app-photos-with-words.md) | app | Maksym | S | — | done |
| T3 | [Keep the photo tab's height and the review-only design variant in preferences](./T3-infra-panel-preferences.md) | infra | Maksym | S | — | todo |
| T4 | [Add the gesture exclusion service and its Android channel handler](./T4-infra-gesture-exclusion-bridge.md) | infra | Maksym | S | — | todo |
| T5 | [Show a photo from the kept file at preview size, with a not-available placeholder](./T5-ui-photo-preview.md) | ui | Maksym | S | — | todo |
| T6 | [Define the PhotoPanelLook interface and build look A](./T6-ui-look-interface-and-look-a.md) | ui | Maksym | M | T3, T5 | todo |
| T7 | [Draw the photo tab in an overlay and let it be dragged up or down](./T7-ui-photo-panel-overlay-and-tab.md) | ui | Maksym | M | T2, T3, T6 | todo |
| T8 | [Open the panel half-open and full-open, settle at stops, and step back](./T8-ui-open-settle-and-close.md) | ui | Maksym | M | T1, T7 | todo |
| T9 | [Show the large photos in full-open with zoom and neighbour-only decoding](./T9-ui-full-open-viewer.md) | ui | Maksym | M | T8 | todo |
| T10 | [Send the tab or handle rectangle to the gesture exclusion service at every change](./T10-wiring-gesture-exclusion-sends.md) | wiring | Maksym | S | T4, T8 | todo |
| T11 | [Make every panel state reachable and closable with a screen reader](./T11-ui-panel-semantics.md) | ui | Maksym | S | T9 | todo |
| T12 | [Give the word list a ScrollController, row keys, a row highlight and the jump to a row](./T12-ui-row-highlight-and-jump.md) | ui | Maksym | M | — | todo |
| T13 | [Mount the photo panel on the main screen with Back stepping, highlight and jump](./T13-wiring-mount-panel-on-main-screen.md) | wiring | Maksym | M | T8, T12 | todo |
| T14 | [Make an open panel own the main screen's touches and close on a session change](./T14-wiring-touch-ownership-and-session-change.md) | wiring | Maksym | M | T13 | todo |
| T15 | [Keep the tab on every pager page and open the panel only over the words page](./T15-ui-pager-integration.md) | ui | Maksym | M | T14 · roadmap #22 merged | todo |
| T16 | [Build design variant B](./T16-ui-look-b.md) | ui | Maksym | M | T11 | todo |
| T17 | [Build design variant C](./T17-ui-look-c.md) | ui | Maksym | M | T11 | todo |
| T18 | [Add the temporary "Photo panel design" choice to Settings](./T18-ui-settings-design-choice.md) | ui | Maksym | S | T3 | todo |
| T19 | [Run the panel behaviour suite against every look and write the device-pass checklist](./T19-tests-all-looks-suite-and-device-pass.md) | tests | Maksym | M | T10, T15, T16, T17, T18 | todo |
| T20 | [Keep the picked look and remove the others, the variant choice and its key](./T20-wiring-design-pick-cleanup.md) | wiring | Maksym | S | T19 · owner's design pick | todo |

**Total:** 20 tasks, ~15.5 person-days.
