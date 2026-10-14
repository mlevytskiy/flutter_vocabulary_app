# Device pass — side-bar-for-main-screen

The owner's checklist for the review build, before the design pick (T20) and before release.
It covers every spec [§6](./spec.md#6-non-functional-requirements) non-functional requirement and every
[§7](./spec.md#7-metrics--kpis) KPI, with the method from [sad §10](./sad.md) (QG-1 to QG-3c). The widget
suite `test/photo_panel_test.dart` already runs AC-01 to AC-18 once per design on the real main screen.
This pass covers what only a phone can show.

## Setup

- **Phone:** the owner's Android phone, Android 10 or later, **gesture navigation on** (Settings → System → Gestures → System navigation).
- **Builds:**
  - The review build (`flutter build apk --profile`) for the frame overlay and the memory profiler.
  - A release build of this branch for the timed runs.
  - A build of `master` before this feature for the start-time baseline.
- **Sessions to prepare:**
  - **S-50:** one session with 50 photos with words (one photo, one or two word rows each).
  - **S-200:** one session with 200 word rows, with a photo whose first row is near the end of the list.
  - **S-dlg:** one session from a subtitle import with "Get dialogues from subtitles" on, so the main screen has dialogue pages, plus at least one photo with words.
  - **S-0:** one session with no photos (typed by hand or from a Quizlet set).
- **Design:** pick it in Settings → "Photo panel design" (Design A, B or C). Run every table below once per design.
- **Recording:** use the phone's screen recorder; read the times frame by frame.

## Checks

Fill one table per design. A row passes when **Result** meets **Target**.

### Design A — card tab, sideways full-open

| # | Check | Spec | Target | Method | Result | Pass? |
|---|---|---|---|---|---|---|
| A1 | Gesture safety | §6 Gesture safety, §7 Gesture misfires, AC-12, AC-13 | 0 Back or page changes in 20 drags started on the tab | S-dlg. 10 drags on the words page and 10 on a dialogue page: left, up and down, some starting at the very right edge. Count every time the app leaves, Back fires, or the page flips before the panel opens. Then swipe in from the right edge **away from** the tab: it must still be Back. | | |
| A2 | Opening from a tap | §6 Opening from a tap, AC-03 | half-open fully settled ≤ 300 ms after the tap | S-50. Screen recording, 10 taps on the tab. Time from the frame the finger lands to the first frame where the panel no longer moves. Write the slowest. | | |
| A3 | Animation smoothness | §6 Animation smoothness | ≤ 5 % dropped frames | Profile build, performance overlay on. S-50: 10 runs of: drag the tab open, let it settle, expand to full-open, drag back. Count the red bars. | | |
| A4 | Main screen start with many photos | §6 Main screen start | start to first word row visible grows by ≤ 100 ms over `master` | S-50 as the current session. Cold start 5 times on `master` and 5 times on this build. Time from the tap on the app icon to the first word row on screen. Write both medians and the difference. | | |
| A5 | Memory for previews | §6 Memory for previews | tab + half-open panel ≤ 30 MB of picture memory | Profile build, DevTools → Memory. S-50: snapshot with the panel closed, then half-open and scrolled to the end of the column. Write the image-cache growth. Also note full-open after browsing all 50 (no target, sad §11). | | |
| A6 | Jump to a photo's words | §6 Jump to a photo's words, AC-04 | first highlighted row in view ≤ 500 ms after the tap | S-200. Screen recording. Open half-open and tap the photo whose first row is near the end. Time from the tap to the row fully in view. 5 runs; write the slowest. | | |
| A7 | Photo taps that highlight words | §7 Photo taps that highlight words | 100 % of taps that select a photo highlight at least one word row | S-50 and S-200. Tap 20 different photos in half-open. Count the selections that show no highlighted row. | | |
| A8 | Nothing changes without photos | AC-02, QG-3c | no tab; the main screen as on `master` | S-0. Compare the main screen with `master` side by side. Then delete the last word row of a photo in S-50: its preview leaves at once (AC-15). | | |
| A9 | Screen reader | AC-18 | every state reachable and closable without a drag | TalkBack on. S-50: the tab reads "Session photos, 50". Double-tap opens half-open. "Show photos large" opens full-open. "Back to small photos" and "Close photos" close it. | | |

### Design B — pill tab, vertical list full-open, tab hides while scrolling

| # | Check | Spec | Target | Method | Result | Pass? |
|---|---|---|---|---|---|---|
| B1 | Gesture safety | §6 Gesture safety, §7 Gesture misfires, AC-12, AC-13 | 0 Back or page changes in 20 drags started on the tab | As A1. Also: scroll the list, and while the tab is faded out, check that the right-edge Back works where the tab was. | | |
| B2 | Opening from a tap | §6 Opening from a tap, AC-03 | ≤ 300 ms | As A2. | | |
| B3 | Animation smoothness | §6 Animation smoothness | ≤ 5 % dropped frames | As A3. | | |
| B4 | Main screen start with many photos | §6 Main screen start | ≤ 100 ms over `master` | As A4. | | |
| B5 | Memory for previews | §6 Memory for previews | ≤ 30 MB | As A5. | | |
| B6 | Jump to a photo's words | §6 Jump to a photo's words, AC-04 | ≤ 500 ms | As A6. | | |
| B7 | Photo taps that highlight words | §7 Photo taps that highlight words | 100 % | As A7. | | |
| B8 | Nothing changes without photos | AC-02, QG-3c | no tab; as on `master` | As A8. | | |
| B9 | Screen reader | AC-18 | every state without a drag | As A9. | | |

### Design C — dark film-strip tab, vertical paging full-open

| # | Check | Spec | Target | Method | Result | Pass? |
|---|---|---|---|---|---|---|
| C1 | Gesture safety | §6 Gesture safety, §7 Gesture misfires, AC-12, AC-13 | 0 Back or page changes in 20 drags started on the tab | As A1. | | |
| C2 | Opening from a tap | §6 Opening from a tap, AC-03 | ≤ 300 ms | As A2. | | |
| C3 | Animation smoothness | §6 Animation smoothness | ≤ 5 % dropped frames | As A3. | | |
| C4 | Main screen start with many photos | §6 Main screen start | ≤ 100 ms over `master` | As A4. | | |
| C5 | Memory for previews | §6 Memory for previews | ≤ 30 MB | As A5. | | |
| C6 | Jump to a photo's words | §6 Jump to a photo's words, AC-04 | ≤ 500 ms | As A6. | | |
| C7 | Photo taps that highlight words | §7 Photo taps that highlight words | 100 % | As A7. | | |
| C8 | Nothing changes without photos | AC-02, QG-3c | no tab; as on `master` | As A8. | | |
| C9 | Screen reader | AC-18 | every state without a drag | As A9. | | |

## Design pick

§7 KPI **Design pick**: the owner picks one design within one review session on the phone.

| Picked design | Date | Why | Notes for T20 |
|---|---|---|---|
| A | 2026-10-14 | Owner: "I will use design A always" | B, C, `looks.dart`, the Settings choice and `photo_panel_variant` removed (T20) |

After the pick, T20 keeps that look and removes the others, the "Photo panel design" choice in Settings
and the `photo_panel_variant` key (AC-20). The checks for the picked design are repeated on the release
build before release.
