---
status: Final
owner: "Maksym"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-06"
feature_size: "S"
---

# Spec — learn-part-step-1

> **Glossary:** [CONTEXT](./CONTEXT.md) · repo-root [CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** None beyond the interview, the two CONTEXT files, [`docs/roadmap.md`](../../roadmap.md), [`docs/architecture.md`](../../architecture.md) and a hand-made mnemonic-story sample the owner showed (not kept in the repo).

## 1. Context

The app collects words and hands them to AnkiDroid, but it has no place where the learner or the partner practises a session's words. The owner wants a learning part, built step by step. The owner's words: "I want add learning part of my application. We are not going to implement learning progress check, but it definitely will be in feature. … For now we are going to implement this page where we pick exercises, but all exercises except mnemonic story will be disabled for now. We should show the page in mobile and web versions." The full exercise plan has three stages. Step 1: Mnemonic story, Match synonyms, Match antonyms, Match word and definition. Step 2: pick the right answer from 4 variants for a definition or translation, guess the word in context (fill the gaps), and cards you mark as remembered or not. Step 3: make your own sentences, translate sentences, and the spoken versions of both.

Why now: the owner has a hand-made mnemonic story for a real session (ten frames, one word each). The way into learning has to exist before any exercise can ship behind it. This step builds that way in and settles its shape before the first exercise needs it.

Committed approach: a Learn button opens a learn page in two places. In the app it sits on the Words screen's top bar, between the back arrow and the title, styled like Share. On the web it sits on the shared page next to "Download for AnkiDroid". The learn page lists all eleven exercises in their three stages, each with a tick box. Only Mnemonic story can be ticked; the other ten are greyed and labelled "Coming soon". Start is enabled while at least one exercise is ticked, and opens a coming-soon screen for the picked exercise, with a way back. The story itself is the next feature. The page saves nothing; ticks last for one visit. The web learn page is an ordinary page served beside the shared page, with its own link, not the app's code built for the browser: the owner chose a fast first load over writing each exercise once for both (2026-10-06). Research (2026-10-06) found no product that puts a word list's exercises on one screen, grouped into visible stages, with several exercises ticked at once. Quizlet and Vocabulary.com launch one mode at a time, and Quizlet's choice of question types is buried in a settings menu. This step builds that staged page with its tick boxes, reachable from the app and from a shared link. Ticking several exercises at once becomes possible when a second exercise becomes available. The sharpest failure found is a Start that leads nowhere and looks broken, so Start has to land somewhere honest (AC-05).

- The roadmap's Out-of-scope line "Own learning / spaced-repetition engine — learning is outsourced to AnkiDroid" is removed by owner decision (2026-10-06). The decision "the app collects and exports, it does not teach" is superseded by this spec. The app now teaches as well as collects. AnkiDroid stays the export target.
- On narrow phones the Words top bar must still fit the back arrow, Learn, the title and Share. There, Learn and Share get smaller padding. Where even that is not enough, they keep only their icons. Wider screens keep Share exactly as it is today (AC-11, AC-11b, AC-12).

## 2. Goals

- The learner can reach a learn page from any Words screen that has words, in the app, and anyone holding a shared link can reach the same page on the web.
- The learn page shows the whole learning plan (three stages, eleven exercises) and is honest about what works today, so every later exercise ships by switching it on rather than by redesigning the page.
- Adding Learn costs the Words screen nothing it has today: on a narrow phone, every top-bar item stays readable and tappable.

## 3. Non-goals

- **The mnemonic story itself:** generating and showing the story is the next feature. Here Start only reaches a coming-soon screen.
- **The other ten exercises:** they are listed and greyed. Each ships as its own later step.
- **Learning progress:** no results, scores, history, "memorized" marks or remembered ticks, on the device or on the web. The owner plans progress for later. Nothing here may block it, but nothing is stored now.
- **Spaced repetition** (bringing a word back after growing pauses): not in this step. Nothing here schedules reviews.
- **Changing the shared page's table, photos or download:** the only change on the shared page is one added button.

## 4. User stories

### US-01: Open the learn page in the app

**As a** learner
**I want** a Learn button on the Words screen of a session that has words
**So that** I can start practising exactly those words

### US-02: See the learning plan and pick exercises

**As a** learner
**I want** to see every exercise grouped by stage, and tick the ones I want
**So that** I know what is coming and choose what to do now

### US-03: Start the picked exercises

**As a** learner
**I want** to press Start after ticking exercises
**So that** I go to the practice itself, or am told clearly that it is not built yet

### US-04: Learn from a shared link

**As a** partner
**I want** a Learn button on the shared page that opens the same learn page
**So that** I can practise the session's words without the app

### US-05: Keep the Words top bar usable on a narrow phone

**As a** learner
**I want** the back arrow, Learn, the title and Share to fit on a narrow phone
**So that** adding Learn does not cut off the title or make buttons hard to hit

## 5. Acceptance criteria

"Word to learn" is defined in [CONTEXT](./CONTEXT.md): a row with an English word plus a translation or a definition. On the web, only the session's saved rows at the moment Learn is pressed or the learn page is loaded count.

### AC-01 (US-01) — happy path

**Given** a learner opens the Words screen of a session with at least one word to learn
**When** the learner looks at the top bar
**Then** the bar shows, from left to right, the back arrow, a Learn button with a graduation-cap icon and the label "Learn", the title "Words" and the Share button. Learn looks like Share (the same white button style).

### AC-02 (US-01) — happy path

**Given** a learner is on the Words screen of a session with at least one word to learn, whether it is the current session or an older session opened from History
**When** the learner taps Learn
**Then** the learn page for that session opens, and the back arrow returns to the same Words screen

### AC-03 (US-01) — domain invariant

**Given** a learner opens the Words screen of a session with no word to learn ("No words added yet")
**When** the learner taps Learn
**Then** the learn page does not open, and the learner is told "No words to learn" (as Share says "No words to share"), because a session with no word to learn offers no way into the learn page

### AC-04 (US-02) — happy path

**Given** the learn page is open
**When** the learner looks at it
**Then** under the title it shows how many words to learn the session has (for example "12 words"), then three stages headed "Step 1", "Step 2" and "Step 3", in this order:
- Step 1: Mnemonic story · Match synonyms · Match antonyms · Match word and definition
- Step 2: Pick the right answer · Fill the gaps · Remember or not
- Step 3: Make your own sentences · Translate sentences · Make your own sentences (speak) · Translate sentences (speak)

Each exercise has a tick box. Only Mnemonic story can be ticked. The other ten are greyed out and labelled "Coming soon". Nothing is ticked when the page is opened from a Learn button.

### AC-05 (US-03) — happy path

**Given** the learner has ticked Mnemonic story on the learn page
**When** the learner presses Start
**Then** a coming-soon screen opens with the heading "Mnemonic story", the text "Coming soon — this exercise is not ready yet." and a "Back to exercises" button. "Back to exercises", the app's back arrow and the browser's back button all return to the learn page, where Mnemonic story is still ticked.

### AC-05b (US-02) — domain invariant

**Given** the learner ticked Mnemonic story, then left the learn page (back to the Words screen in the app, or back to the shared page on the web)
**When** the learner presses Learn again
**Then** the learn page opens with nothing ticked, because ticks last only for one visit of the learn page and the learn page saves nothing

### AC-06 (US-02) — domain invariant

**Given** the learn page is open
**When** the learner taps a coming-soon exercise, its tick box or its label
**Then** it stays unticked and nothing else changes on the page, because a coming-soon exercise can never be ticked or started

### AC-07 (US-03) — error

**Given** the learn page is open
**When** no exercise is ticked, either when the page opens or after the learner unticks Mnemonic story
**Then** Start is shown as unavailable and does nothing when pressed, and the line "Pick at least one exercise" is shown near Start for as long as nothing is ticked

### AC-08 (US-04) — happy path

**Given** a partner opens the shared page of a published session that has at least one word to learn
**When** the partner presses Learn, which sits right of "Download for AnkiDroid" and looks like it
**Then** the learn page for that session opens at its own link, with the same word count, stages, exercises, order, ticks, coming-soon states and coming-soon screen as in the app (AC-04 to AC-07). On a phone (where the shared page uses its phone layout) it opens in the same tab, and the browser's back button returns to the shared page. On a computer it opens in a new tab, so the shared page, including any cell not saved yet, stays open in its own tab. On a 320 px wide phone screen the learn page needs no sideways scrolling.

### AC-08b (US-04) — happy path

**Given** someone holds the learn page's own link of a live session
**When** they open that link directly
**Then** the learn page opens as in AC-08 if the session has at least one word to learn, and otherwise shows "No words to learn" with a link to the session's shared page

### AC-09 (US-04) — authorization

**Given** someone opens the web learn page of a session whose link has expired or never existed
**When** the page loads
**Then** they see the same "This word list is gone." message the shared page shows for such a link, and nothing reveals whether the session ever existed, because a link is the only credential and a dead link opens nothing

### AC-10 (US-04) — cross-context

**Given** a published session whose saved rows hold no word to learn any more, for example because someone deleted them on the shared page
**When** a partner presses Learn on the shared page
**Then** the web learn page does not open, and the partner is told "No words to learn", even if the learner's session in the app still has words, because the web learn page follows the shared page's saved rows, not the app's

### AC-11 (US-05) — happy path

**Given** a learner opens the Words screen on a phone where the back arrow, Learn, the title "Words" and Share do not fit with today's padding, judged by the space actually available at the phone's system text size
**When** the Words screen is shown
**Then** Learn and Share use smaller padding, so the back arrow, both buttons with their icons and labels, and the full title "Words" are visible without cutting or overlap, and each button is still easy to tap

### AC-11b (US-05) — happy path

**Given** a learner opens the Words screen on a phone where even the smaller padding cannot fit the back arrow, both buttons with their labels and the full title "Words" (for example the narrowest phones with a large system text size)
**When** the Words screen is shown
**Then** Learn and Share drop their labels and show only their icons, the full title "Words" stays visible, and a long press on either icon names it ("Learn", "Share")

### AC-12 (US-05) — domain invariant

**Given** a learner opens the Words screen on a phone where everything fits with today's padding
**When** the Words screen is shown
**Then** Share looks exactly as it does today (same padding, icon and label), and Learn matches it

### AC-13 (US-01) — cross-context

**Given** a learner opens the Words screen of an older History session that is not the current session, and the two sessions hold different numbers of words to learn
**When** the learner opens the learn page from it
**Then** the learn page shows the History session's word count, not the current session's, and the current session is not changed (it does not become current, and nothing in it changes)

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| App learn page open time | ≤ 300 ms from tapping Learn to the page shown | stopwatch / frame timeline on the owner's phone, 5 runs, at release |
| Web learn page load | ≤ 1.5 s to the page shown on a phone over 4G | 5 loads in a phone browser at release |
| Narrow top bar | the layout is chosen by measuring the space actually available, not by fixed width thresholds. 360 dp at 100 % text size: labels shown (normal or smaller padding). 320 dp at 100 % and at 130 %: no cut-off and no overflow in whichever layout is chosen | device or emulator pass at release, plus widget tests at 360 dp/100 %, 320 dp/100 % and 320 dp/130 % |
| Web learn page on a phone | no sideways scrolling at 320 px viewport width | browser device emulation at 320 px at release |
| Same plan on app and web | 11 of 11 exercises match in name, stage, order and state | a check at release comparing both pages, plus a test that compares the app's and the web page's exercise lists |
| Tap target | each top-bar button ≥ 48 × 48 dp, also in compact and icon-only layouts | widget test at 320 dp |

## 6.1 Security / privacy

- **Data classification:** public. The web learn page shows the exercise names and the session's word count, which the shared page already shows. Anyone with the link can already see the session.
- **Personal data touched:** none. Nothing new is stored on the device or on the web.
- **AuthZ/AuthN impact:** none added. The web learn page is reached through the session's link, like the shared page, with the same rule for dead links (AC-09).
- **Abuse cases:**
  - Guessing links to learn pages: same as guessing shared-page links. A dead or unknown link answers exactly like an expired one (AC-09).
  - Old links gain a Learn button: every published session inside its 30 days shows Learn as soon as this ships, without a republish. Accepted: the button only reads the session.
  - Heavy reloading of the web learn page: not rate-limited, the same as reading the shared page today (only page edits are rate-limited). Accepted on purpose: the page only reads. If reading the shared page ever gets a limit, the learn page gets the same one.
- **Security review:** N/A. No new data, no new permission, no new way to change a session.

## 7. Metrics / KPIs

- **Learn used:** baseline 0 (no Learn today), target the owner opens the learn page from ≥ 3 different sessions within 14 days of release, counted by the owner.
- **Partner reach:** baseline 0, target the learn page opened from ≥ 1 shared link by someone other than the owner within 30 days, as reported by the owner.
- **Top bar on narrow phones:** baseline unmeasured, target 0 reports of a cut-off title or overlapping buttons within 30 days of release.

## 8. Open questions

- [ ] Roadmap step 8 ("mark one memorized") overlaps with the planned "Remember or not" exercise. Keep step 8 as a separate feature or fold it into the learning part? Default now: step 8 stays as it is, untouched by this feature. — owner: Maksym, due: before `sdd:specify` of the "Remember or not" exercise
