---
status: approved
feature_size: "M"
updated_at: "2026-10-06"
---

# UX flows — import-from-quizlet

> User flows for every UI-touching §4 user story of [spec.md](./spec.md), produced by `ux-flows` (after `clarify`, before `design`) and read by `design` (evidence for the target-surface + UI-architecture decisions), `sequences` (UI-driven flows align on SCR ids), `screens` (details every inventory row) and `plan-tests` (the e2e-through-UI paths). **Always markdown + mermaid `flowchart`**, whatever the design tool — this artifact is flow-altitude, not visual design.

## Platform decisions

- **Posture:** the import is phone-app only, like the subtitle import; the set source on the shared page reuses good-looking-web's two existing layouts — wide (source pager in the right corner) and phone (stacked-thumbnail button opening a swipeable dialog). Owner's choice, 2026-10-06. There is no `docs/design-system.md` yet.
- **Everything in the app happens in dialogs over the main screen.** "Import from Quizlet" in the red + menu opens the link dialog; Start closes it and shows the progress dialog; the cards arrive in the existing results dialog. There is no import screen.
- **The progress dialog shows a pager of the set's cards, not the page** (owner review 2026-10-06, spec AC-02): skeleton cards under a skeleton title for at least 1 second, then the set's name and its cards (term and back side), scrolled by themselves from the first card to the last in 2 seconds, then the results dialog. The Quizlet page loads out of sight under the cards. When Quizlet shows its own "I'm not a robot" check, the page itself is shown at full size in place of the cards and the cards come back once it is passed (AC-05).
- **The link dialog shows how to get the link** (owner review 2026-10-06, AC-01): above the field a short animation sketches a set page, a finger tapping Share, then Copy link, a "Link copied" note, and a pointer down to the field, with the step named under it. It plays three times, a tap replays it, and it stops once the field has text. The field is styled like the Word and Translation fields, and with the keyboard up the field stays in sight while the animation scrolls away above it (second owner review).
- **The red + menu** (owner review 2026-10-06, AC-01): "From subtitles" is dark grey with the captions icon; "Import from Quizlet" is blue with a white Quizlet-like "Q", and "Get words from photo" is green. The Settings button bottom-left rises with the + button above a SnackBar (second owner review).
- **The progress dialog can be cancelled** (Cancel or Back), quietly, with the session unchanged (AC-07b). While it shows, the learner cannot switch sessions; a session change that still happens is caught by the late-result rule (AC-16).
- **Errors after Start close the progress dialog and show a message on the main screen** with the session unchanged (AC-07). A pasted text without a set link is refused inside the link dialog, before Start, and the text is kept (AC-06).
- **Trying again means opening "Import from Quizlet" again** from the red + menu.
- **On the shared page the set source is one more page of the existing source pager / sources dialog**, next to the photos. Choosing its link leaves the shared page for Quizlet in a new browser tab.
- **Design input flagged, not decided here:** how the app reads the page it loads behind the cards, and how the 30-second wait is paused during Quizlet's robot check.

## Screen inventory

| ID | Screen | Purpose | Entry | Exit |
|---|---|---|---|---|
| SCR-01 | Main screen (word input) | The current session's words; the red + menu shows "From subtitles" in dark grey with the captions icon and "Import from Quizlet" in blue with a white Quizlet-like "Q" where Screenshot was; messages after a failed import appear here | App launch; any app dialog below closing | SCR-02 from the red + menu; SCR-09 from the side menu |
| SCR-02 | Quizlet link dialog | A short how-to animation (open the set, Share, Copy link, paste below) above the field; paste text holding a Quizlet set link, then Start; refuses text without a set link and keeps it | "Import from Quizlet" in the SCR-01 red + menu | SCR-03 on Start; closed back to SCR-01 |
| SCR-03 | Progress dialog with cards pager | "Reading the Quizlet set…", a skeleton title and skeleton cards for at least 1 s, then the set's name and its cards scrolled first to last in 2 s; the set's page itself at full size for Quizlet's own robot check; Cancel | Start in SCR-02 | SCR-04 when the cards are read; SCR-01 on cancel (quiet) or failure (message) |
| SCR-04 | Results dialog | The set's name, the proposed words (word, translation, definition), the "Read X of Y" and skipped-cards lines when they apply, each word removable; Done adds the rest | Cards read while SCR-03 shows | Done or close → SCR-01 |
| SCR-05 | Words screen share sheet | Choose file or link; the "Include photos (N)" switch above the table (photos only) with its 30-day notice; set sources are always published | Share on the words table (SCR-09) | The link dialog / shared link on publish; back to SCR-09 |
| SCR-06 | Shared page, wide layout | The word table with the source pager in the right corner; the pager has a page per source photo and per set source; rows from the current source highlighted | Opening the shared link on a wide screen | SCR-10 through a set source's link; SCR-07 when the window narrows |
| SCR-07 | Shared page, phone layout | The scrollable word table with the stacked-thumbnail sources button | Opening the shared link on a narrow screen | SCR-08 from the sources button; SCR-06 when the screen widens |
| SCR-08 | Sources dialog (phone) | Swipe between the source photos and the set sources; a set page shows its name and link | The sources button on SCR-07 | Closed back to SCR-07; SCR-10 through a set source's link |
| SCR-09 | Words table, History and AnkiDroid export | Existing places where a session's words are viewed, reopened and exported | Side menu on SCR-01 | Back to SCR-01; SCR-05 through Share; the exported file |
| SCR-10 | Quizlet set page (outside the app) | The set on Quizlet, opened from the shared page in a new browser tab | A set source's link on SCR-06 or SCR-08 | Closing the tab |

## Flows

### Flow: US-01 — Import a set from its link

```mermaid
flowchart TD
    A[SCR-01 Main screen] -->|Import from Quizlet in the red + menu| B[SCR-02 Link dialog]
    B -->|close| A
    B -->|paste text and Start| V{Text holds a Quizlet set link?}
    V -->|no| E1[SCR-02 Paste a link to a Quizlet set, text kept]
    E1 -->|fix the text and Start| V
    V -->|yes| K[SCR-03 Progress dialog with skeleton title and cards, at least 1 s]
    K --> P[SCR-03 Set name; cards once read]
    P -->|Quizlet shows its robot check| C[SCR-03 The page at full size instead of the cards]
    C -->|learner passes the check| P
    P -->|Cancel or Back| Q[SCR-01 Session unchanged, no message]
    P -->|cards read| AS[SCR-03 Cards scroll first to last in 2 s]
    AS --> S{Still the session the import started in?}
    S -->|no| X[SCR-01 Words dropped, both sessions unchanged]
    S -->|yes| R[SCR-04 Results dialog with the set name]
```

The learner opens the red + menu, where "Import from Quizlet" sits in blue with a white Quizlet-like "Q" in Screenshot's old place, and the link dialog opens, with a short animation above the field showing how to copy a set's link in Quizlet (AC-01). Closing it changes nothing. If the pasted text holds no Quizlet set link, the dialog says to paste one and keeps the text to fix (AC-06). Any text holding a set link starts the import: the progress dialog shows "Reading the Quizlet set…" over a skeleton title and skeleton cards for at least a second, then the set's name once known and, once read, the set's cards, which scroll by themselves from the first to the last in two seconds (AC-02). If Quizlet shows its own robot check, the page itself is shown at full size in place of the cards until the learner passes it (AC-05). Cancel or Back returns to the main screen quietly (AC-07b). When the cards are read and the session is still the one the import started in, the results dialog opens; if the session changed meanwhile, the words are dropped (AC-16). The failure branches are drawn in the US-03 flow.

### Flow: US-02 — Review the cards before adding

```mermaid
flowchart TD
    R[SCR-04 Results dialog] --> N{Any card left after skipping?}
    N -->|no| Z[SCR-04 No new words in this set, with the skipped-cards line]
    Z -->|Done or close| U[SCR-01 Session unchanged, no set source added]
    N -->|yes| K{Fewer cards found than the set's own count?}
    K -->|yes| L1[SCR-04 Read X of Y cards line shown]
    K -->|no| L2[SCR-04 All cards in set order]
    L1 --> W[SCR-04 Learner removes words]
    L2 --> W
    W -->|Done with words left| D[SCR-01 Kept words added at the end, linked to the set source]
    W -->|Done with every word removed, or close| U
```

The results dialog lists the cards in set order, each as the word with the card's back side as its translation (a Ukrainian back) or its definition (any other back) and the example in the definition; a field the card does not fill has no line (AC-02); cards with no text term and duplicates are already left out and named in one skipped-cards line (AC-09, AC-10). If every card was skipped, the dialog says "No new words in this set." and Done changes nothing (AC-04b). If fewer cards were found than the set says it has, a "Read X of Y cards" line shows (AC-08). The learner removes the words they don't want; Done adds the rest at the end of the current session in set order, each linked to the set source, and a set imported before stays one source with the newer name (AC-03, AC-13b). Removing every word, or closing the dialog, leaves the session unchanged with no set source (AC-04).

### Flow: US-03 — Understand what went wrong

```mermaid
flowchart TD
    B[SCR-02 Link dialog] -->|Start with text holding no set link| E1[SCR-02 Paste a link to a Quizlet set, text kept]
    B -->|Start with a set link| P[SCR-03 Progress dialog]
    P -->|page tries to leave Quizlet, or learner taps such a link| F[SCR-03 Not opened, the hidden page stays on the set]
    F --> P
    P --> T{Cards found within 30 s after the page loaded?}
    T -->|yes| R[SCR-04 Results dialog]
    T -->|no: no connection, page failed, private or deleted set, login wall, check from outside Quizlet| M[SCR-01 The cards of this set could not be read, try again]
```

A pasted text without a Quizlet set link is refused before the import starts, with the text kept (AC-06). While the progress dialog shows, a page outside Quizlet — an advert, a store, another site or a robot check served by another company — is never opened, and moving to another Quizlet set reads nothing from it (AC-11). If no cards are found within 30 seconds after the page has loaded (the wait is paused while Quizlet's own check is on screen), the progress dialog closes and the main screen says the cards of this set couldn't be read and the learner can try again, with the session unchanged (AC-07).

### Flow: US-04 — See which set a word came from

```mermaid
flowchart TD
    O([Partner opens the shared link]) --> W{Wide screen?}
    W -->|yes| A[SCR-06 Wide table and source pager]
    A -->|moves the pager to the set source| S[SCR-06 Set name, its link and position 3 of 3, its rows highlighted]
    S -->|chooses the link| Q[SCR-10 Quizlet set page in a new tab]
    W -->|no| P[SCR-07 Phone layout with sources button]
    P -->|taps the sources button| D[SCR-08 Sources dialog]
    D -->|swipes to the set source| DS[SCR-08 Set name and its link]
    DS -->|chooses the link| Q
    DS -->|close| P
```

On a wide screen the partner moves the source pager to the set source and sees the set's name with its plain Quizlet link under it and its position ("3 of 3"); the rows imported from that set are highlighted and the others are not (AC-13). Choosing the link opens the set on Quizlet in a new tab. On a phone the partner taps the stacked-thumbnail sources button and swipes the dialog to the set's page, which shows the same name and link (AC-14).

### Flow: US-05 — Decide what the shared page reveals

```mermaid
flowchart TD
    T[SCR-09 Words table with Include photos N switch, on] -->|Share| S[SCR-05 Share sheet]
    S -->|photos on, publish as link| ON[SCR-06 or SCR-07 Source pager or button with photos and sets]
    S -->|photos off, publish as link| OFF[SCR-06 or SCR-07 Sets only in the pager; no photos]
    S -->|cancel| T
```

Above the words table the switch reads "Include photos (N)", counting the source photos that still have a word in the session; it is on by default and the share sheet says included photos are public for 30 days (AC-15). Set sources are not behind it: a set that still has a word in the session is always published, without asking, and a session whose only sources are sets shows no switch (owner review 2026-10-06). Publishing with it on gives the shared page its pager (wide) or sources button (phone) with photos and sets; switched off, the page shows no photo, and only the sets remain in the pager (AC-12).

### Flow: US-06 — Quizlet words are ordinary words

```mermaid
flowchart TD
    A[SCR-01 Words from a set in the session] -->|side menu| T[SCR-09 Words table]
    A -->|side menu| H[SCR-09 History, session reopened]
    A -->|side menu| X[SCR-09 AnkiDroid export]
    T --> L[Word, translation and definition like other words, no lightning inviting replacement]
    H --> L
    X --> L
```

Words imported from a set show up in the words table, in the session reopened from History and in the AnkiDroid export like any other words: the card's back side in the translation (Ukrainian) or the definition (anything else), the example in the definition, nothing machine-translated. A field the card filled shows no lightning inviting the learner to replace it; a field it left empty shows its lightning as for a typed word (AC-17).

## AC coverage

| AC | Shown by | Notes |
|---|---|---|
| AC-01 | Flow US-01 → SCR-01 to SCR-02 | Menu item in blue where Screenshot was; "Get words from photo" green |
| AC-02 | Flow US-01 → SCR-03 progress with skeleton then cards pager → SCR-04 | Word / translation / definition per card |
| AC-03 | Flow US-02 → Done with words left | |
| AC-04 | Flow US-02 → every word removed, or close | |
| AC-04b | Flow US-02 → no card left after skipping | |
| AC-05 | Flow US-01 → the page at full size instead of the cards | Quizlet's own check only; outside checks → AC-07 |
| AC-06 | Flows US-01 and US-03 → SCR-02 text kept | |
| AC-07 | Flow US-03 → no cards within 30 s | Message on SCR-01 |
| AC-07b | Flow US-01 → Cancel or Back | Quiet |
| AC-08 | Flow US-02 → Read X of Y cards line | |
| AC-09 | Flow US-02 → SCR-04 skipped-cards line | The text rules (line breaks, length) are content, not movement |
| AC-10 | Flow US-02 → SCR-04 skipped-cards line | Matching rule is content, not movement |
| AC-11 | Flow US-03 → not opened, the hidden page stays on the set | |
| AC-12 | Flow US-05 → switched off | |
| AC-13 | Flow US-04 → wide pager set page | |
| AC-13b | Flow US-02 → Done, set imported before stays one source | |
| AC-14 | Flow US-04 → SCR-08 set page | |
| AC-15 | Flow US-05 → SCR-05 switch | |
| AC-16 | Flow US-01 → session changed | |
| AC-17 | Flow US-06 | |
