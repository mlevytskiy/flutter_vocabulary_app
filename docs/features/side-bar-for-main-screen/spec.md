---
status: Final
owner: "Maksym"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-13"
feature_size: "M"
---

# Spec — side-bar-for-main-screen

> **Glossary:** [CONTEXT](./CONTEXT.md) · repo-root [CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** the main screen code (`lib/features/word_input/word_input_screen.dart`, `lib/features/word_input/widgets/word_row_item.dart`) and where photos are kept (`lib/core/services/source_photo_store.dart`, `lib/core/models/session_source.dart`, `lib/core/models/word_pair.dart`).

## 1. Context

Words often come into a session from photos the learner takes, for example of a book page, and every word row remembers which photo it came from. On the phone, those photos cannot be seen again: the main screen shows only the word rows, and the link between a photo and its words exists only on the shared page. The owner wants a panel on the right side of the main screen for the photos behind the vocabulary. The owner's words: "I want to create a new sidebar from the right corner and it should be not on the corner like menu. It should be somewhere on the right side, not on the top corner. … I want to see some stuff that I can drag on it and open side menu. It's also possible to click on it and open it, … maybe near the first card or between first and second card, and when you see it, it can show some information on this small widget with what you can drag and drop it or open it. There should be some information, for example, some mini icon of photos because if I want to show in this sidebar photos that connected to the vocabulary. … And I want to make it a little bit abstract to give possibility for models to create design of it by themselves."

Why now: photo sessions are the app's main way in, and when the learner checks a word they want to look at the page it came from. The owner also wants to try a new way of working: the spec fixes only the behaviour, and two or three looks are built and compared on a phone before one is kept.

Committed approach: on the words page of the main screen, while the current session has at least one photo with words, a photo tab sits on the right side, first beside the first word rows, and shows mini previews of those photos. It stays at its place on the screen while the list scrolls and on every page of the main screen pager, and the learner can drag it up or down to another height, which the app remembers. A tap or a short drag to the left opens the photo panel half-open: a column of small photos beside the still-visible word rows, where tapping a photo scrolls the list to that photo's words and highlights them. A longer drag, or a tap on the panel's expand control, opens it full-open: the photos large, starting at the selected photo, covering the word rows, with the small photos animating into the large ones. Back or a tap on the word list closes it one step at a time; a drag back settles at the nearest stop. Two or three design variants are built behind a temporary switch in Settings; they share the behaviour in AC-01 to AC-18 and may differ only in their look, in how the large photos are browsed in full-open, and in whether the tab hides while the word list scrolls (AC-19). The owner picks one on a phone and the rest are removed. Research (2026-10-12) found no product that links a source photo to the words taken from it inside the word list. Photo vocabulary apps link one word to its photo only. Multi-stop sheets exist only as bottom sheets. Edge handles exist only as system launchers that show no content. The sharpest failure found is the right-edge gesture: on phones with gesture navigation a swipe in from the right edge means Back and would send the app to the background. So a drag that starts on the photo tab must never trigger Back or flip a page, and a tap must open the panel just as well as a drag (AC-12, AC-13).

- The photo tab may overlap the right edge of the word rows beneath it, where each row has its delete, translation-options and lightning controls (owner decision, 2026-10-12). A touch on the tab never reaches the row under it, and every row's controls can be reached by dragging the tab up or down off it, or by scrolling the row out from under the tab (AC-14).
- Making the word rows narrower or rearranging them while the panel is half-open is left for a later feature (owner decision, 2026-10-12).
- While the photo panel is open it is only for looking: any touch on the main screen outside the panel closes it and does nothing else, and the rows are edited after it is closed (owner decision, 2026-10-12; widened to every control, 2026-10-13).
- The photo tab is shown on every page of the main screen pager, at its place, and does not move with a page swipe; opening the panel from a dialogue page first returns to the words page (owner decision at the design critic pass, 2026-10-13; SAD §1).
- This feature builds on the main screen pager with its dialogue pages from get-words-from-subtitles-improvment (roadmap #22). Building this feature starts after #22 is merged, so AC-13 can be checked from the start (owner decision, 2026-10-12).

## 2. Goals

- The learner can see the photos behind the current session from the main screen without leaving it.
- The learner can go from a photo to the word rows that came from it in one tap.
- The owner picks the look of the tab and panel from real, working variants on a phone instead of from drawings.

## 3. Non-goals

- Narrowing or rearranging the word rows while the panel is half-open. The owner left this for a later feature.
- Editing, deleting or adding word rows while the photo panel is open. The owner decided an open panel is only for looking.
- Showing Quizlet sets in the panel. A set has no picture, and the panel is for photos.
- Editing, deleting, cropping or re-taking photos from the panel. The panel only shows photos; changing them is a separate feature.
- The photo panel on the dialogue pages of the main screen (from get-words-from-subtitles-improvment), and the tab and panel on the Words screen, on History, or on the shared page. The tab is shown on the dialogue pages, but opening it returns to the words page first (AC-13).

## 4. User stories

### US-01: Notice my session's photos

**As a** learner
**I want** to see a small tab with previews of my session's photos on the main screen
**So that** I know the photos are there and can open them

### US-02: Find a photo's words

**As a** learner
**I want** to open the photos halfway and tap one
**So that** the list jumps to the words that came from it and shows them highlighted

### US-03: Look at the photos large

**As a** learner
**I want** to open the panel fully and see the photos large
**So that** I can read the page I photographed

### US-04: Close the panel step by step

**As a** learner
**I want** to close the panel by dragging back, with Back, or by tapping the word list
**So that** I return to my words without losing my place

### US-05: Keep the main screen working

**As a** learner
**I want** the tab to stay out of the way of scrolling, the page swipe, Back and my word rows' controls
**So that** adding the tab does not break anything I already do on the main screen

### US-06: Pick the look of the tab and panel

**As a** learner (the owner choosing the look)
**I want** to switch between two or three design variants on my phone
**So that** I keep the one that looks and feels best, and the others are removed

## 5. Acceptance criteria

### AC-01 (US-01) — happy path

**Given** the current session has at least one photo with words
**When** the learner is on the main screen, on the words page or a dialogue page
**Then** the photo tab is shown on the right side and not in a corner, with mini previews of the photos with words; it first sits beside the first word rows, later at the height the learner last dragged it to, and it stays at that place on the screen while the word list scrolls (unless the design variant hides it while scrolling, AC-19) and while the page changes; it always stays between the top bar and the floating buttons, and while the keyboard is open it sits just above the keyboard, returning to its height when the keyboard closes

### AC-02 (US-01) — domain invariant

**Given** the current session has no photo with words: it was typed by hand, came only from a Quizlet set, or every word row from its photos was deleted
**When** the learner is on the main screen
**Then** no photo tab is shown, and nothing on the screen changes from today

### AC-03 (US-02) — happy path

**Given** the photo tab is shown
**When** the learner taps it, or drags it a short way to the left and lets go
**Then** the photo panel settles half-open, showing a small picture of each photo with words, oldest first by when the photo was added to the session, with the word rows still visible beside it; if a word row was being edited, the keyboard closes and what was typed is kept

### AC-04 (US-02) — happy path

**Given** the photo panel is half-open
**When** the learner taps a photo
**Then** that photo becomes the selected photo, the word list scrolls as little as needed so that the first word row from it, in the list as it is shown now, is fully in view beside the panel (it does not move if that row already is), and every word row from it is highlighted

### AC-05 (US-02) — domain invariant

**Given** a photo is the selected photo
**When** the learner taps the same photo again, taps another photo, or the panel closes
**Then** the highlight is removed (or moves to the other photo's rows), and only one photo is ever selected at a time; removing the highlight does not scroll the list

### AC-06 (US-02) — cross-context

**Given** the photo panel is half-open and a photo is selected
**When** the learner scrolls the word list
**Then** the list scrolls, the panel stays half-open, and the highlight stays on the selected photo's rows

### AC-07 (US-03) — happy path

**Given** the photo tab is shown or the panel is half-open
**When** the learner drags it further to the left and lets go, or (from half-open) taps the panel's expand control
**Then** the photo panel settles full-open, covering the word rows and showing the photos large, and the small photos visibly grow into the large ones on the way

### AC-07b (US-03) — happy path

**Given** the photo panel is full-open
**When** the learner looks at the large photos
**Then** the first large photo shown is the selected photo (or the first photo if none is selected); a large photo can be zoomed with two fingers to read it; a tap on a large photo does nothing else; browsing to another large photo does not change the selected photo, and back in half-open the same photo's rows are still highlighted

### AC-08 (US-03) — happy path

**Given** the learner is dragging the tab or the panel
**When** they let go between two stops
**Then** the panel settles at the nearest of closed, half-open and full-open, and never stays in between; a quick flick moves it one stop beyond the stop the drag started from, in the flick's direction, and never skips a stop (so closed to full-open is a long drag or two gestures), and any drag to the left from closed opens at least half-open (AC-03)

### AC-09 (US-03) — error

**Given** a photo with words whose picture can no longer be read on the phone
**When** the photo tab or the photo panel shows it
**Then** a placeholder that says the photo is not available is shown in its place, tapping it in half-open still highlights its word rows, and the other photos show normally

### AC-10 (US-04) — happy path

**Given** the photo panel is full-open or half-open
**When** the learner presses Back, or drags it back to the right
**Then** Back goes one step back (full-open to half-open, half-open to closed); a drag back settles by AC-08, so a long drag from full-open can close it; in full-open the drag back starts on the panel's handle, which is not at the screen's left edge, while a drag on a large photo browses or moves a zoomed photo; a swipe in from the left screen edge is Back and goes one step back, and the drawer does not open while the panel is open; Back never leaves the main screen while the panel is open

### AC-11 (US-04) — happy path

**Given** the photo panel is half-open
**When** the learner touches the main screen outside the panel: the visible part of the word list, the top bar or its menu, the floating buttons, or a swipe in from the left edge for the drawer
**Then** the panel closes and that touch does nothing else: no field is focused, no control is pressed, no screen or menu opens; scrolling the visible word list still scrolls it (AC-06)

### AC-12 (US-05) — cross-context

**Given** the phone uses gesture navigation, where a swipe in from the screen edge means Back
**When** the learner starts a drag on the photo tab
**Then** the drag opens the photo panel, the app is never sent to the background, and a swipe in from the right edge that does not start on the tab still works as Back

### AC-13 (US-05) — cross-context

**Given** the main screen has more than one page (the words page and dialogue pages)
**When** the learner drags the photo tab
**Then** on the words page the photo panel opens and the page does not change; on a dialogue page the main screen first returns to the words page and the panel opens there; while the panel is closed a swipe anywhere else still changes the page as before, and while the panel is half-open or full-open no swipe changes the page; the tab is shown at its place on every page and does not move with a page swipe

### AC-14 (US-05) — domain invariant

**Given** the photo tab overlaps the right edge of a word row
**When** the learner touches the tab
**Then** only the tab responds, and the row's delete, translation-options and lightning controls are never triggered through it; dragging the tab up or down moves it to another height on the screen (a drag to the left still opens the panel; the main direction of the first movement decides, and one drag never does both), so the row's controls can be reached even when the list is too short to scroll; scrolling the row out from under the tab also makes them usable again; the tab's height is kept after the app is closed and opened again

### AC-15 (US-05) — cross-context

**Given** the photo panel is closed or open
**When** a photo's last word row is deleted or has its word cleared, or a new photo adds words to the current session
**Then** the tab and an open panel update at once: a photo with no words left disappears, a new photo appears, and if no photo with words is left the panel closes and the tab disappears; if the selected photo disappears, no photo stays selected

### AC-15b (US-05) — cross-context

**Given** the photo panel is open
**When** the current session changes (picked from History, directly or through the drawer; restored from the offer; or a new session starts)
**Then** the panel closes and no photo stays selected; back on the words page, the tab shows the current session's photos with words, or is not shown if it has none; when the app goes to the background and comes back with the same current session, the panel and the selected photo are as they were

### AC-16 (US-05) — authorization

**Given** the learner has other sessions with their own photos
**When** the photo tab or the photo panel is shown
**Then** only the current session's photos with words appear in it; another session's photos are never shown

### AC-17 (US-05) — cross-context

**Given** the screen is busy analysing a photo
**When** the learner touches the photo tab
**Then** the touch is ignored and the panel stays closed

### AC-18 (US-05) — happy path

**Given** a screen reader is on
**When** the learner moves to the photo tab
**Then** it is announced as the session's photos with their count, a double-tap opens the panel half-open, full-open can be reached from half-open without any drag, and every open state can be closed without any drag

### AC-19 (US-06) — happy path

**Given** a build made for the owner's design review
**When** the owner switches between the two or three design variants
**Then** the tab and panel change at once, and every variant passes AC-01 to AC-18; the switch is a temporary entry in Settings, only for the review; variants differ only in their look (including how highlighted word rows look), in how the large photos are browsed in full-open, and in whether the photo tab hides while the word list scrolls

### AC-20 (US-06) — domain invariant

**Given** the owner has picked one design variant
**When** the feature is released
**Then** only the picked variant remains, the switch is removed from Settings, the learner sees no switch between designs, and nothing about the picked look changes without the owner's approval

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Opening from a tap | half-open is fully settled ≤ 300 ms after the tap | owner's phone, screen recording, 10 taps |
| Animation smoothness (drag, settle, half-open to full-open) | ≤ 5 % dropped frames | performance overlay on the owner's Android phone, profile build, 10 runs |
| Main screen start with many photos | start to first word row visible grows by ≤ 100 ms with 50 photos with words, compared with the same session today | timed start, 5 runs each, owner's phone |
| Memory for previews | the tab and the half-open panel together use ≤ 30 MB of picture memory with 50 photos with words | memory profiler, owner's phone |
| Jump to a photo's words | the first highlighted row is in view ≤ 500 ms after the tap, in a session of 200 word rows | screen recording, owner's phone |
| Gesture safety | 0 Back or page changes out of 20 drags started on the tab | device pass on an Android phone with gesture navigation |

## 6.1 Security / privacy

- **Data classification:** internal. The photos are the learner's own pictures, kept on the phone.
- **Personal data touched:** none new. The panel shows photos the app already keeps. The only new stored value is the photo tab's height on the screen, kept on the phone; nothing new is sent.
- **AuthZ/AuthN impact:** none. The app has no accounts; the panel only shows the current session's photos with words (AC-16).
- **Abuse cases:**
  - Another session's photos shown by mistake: the panel shows only the current session's photos and closes when the session changes (AC-15b, AC-16).
  - A photo shown to someone else: the panel exists only in the app on the learner's phone; the shared page is not changed.
  - A mistaken touch that deletes a row or starts a paid autofill: the tab takes every touch on it (AC-14).
- **Security review:** N/A. Nothing personal is stored, and nothing is sent or opened to anyone new.

## 7. Metrics / KPIs

- **Photo taps that highlight words** — baseline: 0 (no panel), target: 100 % of taps that select a photo in half-open highlight at least one word row, in the owner's device pass before release.
- **Gesture misfires** — baseline: n.a., target: 0 Back or page changes in 20 drags on the tab, before release.
- **Design pick** — baseline: 0 variants, target: the owner picks one variant within one review session on the phone, and the others are removed before release.

## 8. Open questions

- [ ] Two or three design variants? Default now: three. — owner: Maksym, due: before `sdd:screens`
- [ ] In full-open, are the large photos a pager or a scrolling list? Default now: each design variant chooses (allowed by AC-19). — owner: Maksym, due: at the design pick
- [ ] When a selected photo's word rows are far apart, does the learner get a way to step to the next highlighted row? Default now: no; the list scrolls to the first one only. — owner: Maksym, due: before `sdd:tasks`
- [ ] Does the photo tab hide while the word list is being scrolled, to uncover the rows' controls? Default now: each design variant chooses (allowed by AC-19). — owner: Maksym, due: at the design pick
