---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-06"
feature_size: "M"
---

# Spec — import-from-quizlet

> **Glossary:** [project CONTEXT](../../../CONTEXT.md) · [good-looking-web CONTEXT](../good-looking-web/CONTEXT.md) (source photo) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** `docs/architecture.md` · `docs/roadmap.md` · `docs/features/words-from-subtitles/spec.md` (the import-dialog → results-dialog pattern) · `docs/features/good-looking-web/spec.md` (the source photo pager, highlighting and the "include photos" switch) · `lib/features/word_input/widgets/word_input_speed_dial.dart` (the red + menu) · `lib/features/word_input/widgets/vocab_result_dialog.dart` (the results dialog) · the owner's example set `https://quizlet.com/ar/987534268/job-interview-flash-cards/?i=xxug6&x=1jqt`

## 1. Context

A learner who already studies with Quizlet has word lists there, their own or ones other people made, and has no way to bring them into the app except typing each word again. Today words come into a session typed by hand, from a photo, or from a subtitle file. A Quizlet set is already a clean list of words with their meanings, so retyping it is pure waste.

Why now: the owner keeps job-interview and other vocabulary in Quizlet sets and wants them in the same sessions, shared page and AnkiDroid export as the rest of their words. The pieces are in place. The results dialog already lets the learner remove unwanted words before Done adds the rest. The shared page already shows where words came from: a pager of source photos with the rows from the current photo highlighted (good-looking-web). And the red + menu has a slot that is no longer needed: Screenshot, whose job the shared link and the file export now do.

Committed approach: a new "Import from Quizlet" item takes the Screenshot item's place in the red + menu, with the same green colour, and Screenshot is removed. It opens a dialog for a Quizlet set link. The app opens the set's page inside the app and reads the set's name and cards on the phone itself, with no server step. Each card's term becomes the English word and its back side becomes the translation, unchanged. The cards open in the same results dialog as a photo or subtitle import, and Done appends the kept words to the current session. Each kept word remembers the set as its source, so on the shared page the set appears in the source pager next to the photos, as the set's name and its link, with its rows highlighted like a photo's. Grounding: the tools compared (Quizlet-to-Anki add-on, the quizlet-fetcher parser, Knowt and other browser extensions, Quizlet's own Export) all work either from a desktop browser that has already passed Quizlet's robot check or from an owner-only export; none imports a set from a link on a phone (research 2026-10-06). A plain automated read of the owner's link is refused with a robot check, which is why the page is opened inside the app where the learner can pass that check. The sharpest failure found is the card's back side not being a Ukrainian translation (the owner's example set has English explanations); the owner accepts that and removes or edits such words, and AC-09 keeps long backs from breaking publishing.

- Decision (owner, 2026-10-06): the Screenshot item, its capture code and the `screenshot` package are removed; CLAUDE.md rule 3 is updated to stop listing `screenshot` (rule 5 approval given).
- Decision (owner, 2026-10-06): one new app package for showing a web page inside the app is approved (CLAUDE.md rule 5); which one is chosen in `design`.
- Decision (owner, 2026-10-06): the card's back side goes into the translation unchanged, even when it is not Ukrainian.
- Decision (owner, 2026-10-06): no limit on the number of cards per import.
- Decision (owner, 2026-10-06): the share sheet's "Include photos" switch becomes "Include sources" and covers source photos and set sources together.
- Decision (owner, critic resolution 2026-10-06): the set source — a Quizlet set kept as its name and link, on word rows, on the session and in the published session — is a new domain model approved under CLAUDE.md rule 5.
- Decision (owner, critic resolution 2026-10-06): a published session has no limit on its sources; this lifts the 10-photo limit good-looking-web set and closes its OQ-3.
- Decision override: size kept at M although the feature touches the app, the server and the shared page — rationale: each part is a small extension of an existing path (the import dialog, the publish format, the source pager), as in good-looking-web.
- Decision override: product names (Quizlet, AnkiDroid, the compared tools, the `screenshot` package, the iPhone share extension) stay in §1–§3 — rationale: they name the outside product this feature imports from and the owner's decisions, not technology choices; the web-page package itself is left to `design`.
- Decision (owner, 2026-10-06): no KPIs are kept for this feature (§7).
- Decision (owner, 2026-10-06): taking a link shared from the Quizlet app (the app as a share target) is a later feature; this one takes a pasted link.

## 2. Goals

- A learner turns a Quizlet set into reviewed words in the current session from its link, without typing any word.
- Words from a Quizlet set behave like any other words afterwards: same session, History, shared page and export.
- The partner can see which Quizlet set a word came from and open it, the same way they see which photo a word came from.

## 3. Non-goals

- Sharing a link from the Quizlet app straight into this app — wanted later; it needs the app to become a share target, a second new package and an iPhone share extension.
- Private, password-protected or login-only sets — the learner is never asked to log in to Quizlet inside the app, so the app holds no Quizlet login.
- Images and audio on cards — only text is read; a card with no text term is skipped.
- Re-importing a set later to pick up changes, or importing Quizlet folders and classes — one set per import, read once.
- Translating a card's back side or checking that it is Ukrainian — the owner accepts the back side as it is (§1 decision).
- Changing anything on Quizlet — the set is only read.

## 4. User stories

### US-01: Import a set from its link
**As a** learner
**I want** to paste a Quizlet set link from the red + menu and get its cards as words
**So that** I don't retype a list I already have

### US-02: Review the cards before adding
**As a** learner
**I want** to see the set's words with their translations and remove the ones I don't want
**So that** only words I chose enter my session

### US-03: Understand what went wrong
**As a** learner
**I want** a plain message when the link is not a Quizlet set or its cards can't be read
**So that** I know whether to fix the link or try again

### US-04: See which set a word came from
**As a** partner
**I want** the shared page to show the Quizlet set's name and link in the source pager, with its words highlighted
**So that** I know where these words came from and can open the set

### US-05: Decide what the shared page reveals
**As a** learner
**I want** one switch that publishes or hides all sources, photos and Quizlet sets alike
**So that** I can share just the word list when I prefer

### US-06: Quizlet words are ordinary words
**As a** learner
**I want** words from a Quizlet set to work like my other words
**So that** they appear in History, the words table and the AnkiDroid export as usual

## 5. Acceptance criteria

### AC-01 (US-01) — happy
**Given** a learner on the main screen
**When** the learner opens the red + menu
**Then** it shows "Get words from photo", "From subtitles" and "Import from Quizlet" in green where Screenshot used to be, and no Screenshot item; choosing "Import from Quizlet" opens a dialog asking for a Quizlet set link

### AC-02 (US-01, US-02) — happy
**Given** a learner in the Quizlet dialog with the link of a public set of 40 cards, in any of the shapes Quizlet gives out (with or without a language part in the address, with or without the sharing extras Quizlet adds at the end)
**When** the learner starts the import
**Then** the set's page opens inside the app, and once its cards are read the results dialog opens with the set's name at the top and all 40 cards in set order, each showing the card's term as the word and the card's back side as the translation

### AC-03 (US-02) — happy
**Given** the results dialog shows 40 cards from a set
**When** the learner removes 3 of them and taps Done
**Then** the 37 kept words are added at the end of the current session on the main screen in set order, each remembering the set as its source, and the 3 removed words are not added

### AC-04 (US-02) — happy
**Given** the results dialog for a set is open
**When** the learner removes every word and taps Done, or closes the dialog without Done
**Then** the current session is unchanged and the set is not a source of the session

### AC-05 (US-01) — happy
**Given** Quizlet shows a robot check when the set's page opens inside the app
**When** the learner passes the check on that page
**Then** the import continues and reaches the results dialog without the learner pasting the link again

### AC-06 (US-03) — error
**Given** a learner in the Quizlet dialog
**When** the learner starts an import with text that is not a link to a Quizlet set (a link to another site, a Quizlet folder or class, or plain words)
**Then** the import does not start and the dialog says to paste a link to a Quizlet set, keeping the text so it can be fixed

### AC-07 (US-03) — error
**Given** an import is running
**When** there is no connection, the page does not load, or no cards can be found on it (a private or deleted set, a login wall, or a Quizlet page the app no longer understands)
**Then** no words are proposed, the learner is back on the main screen with the current session unchanged, and the app says the cards of this set couldn't be read and they can try again; the learner can always leave the in-app page with Back or Close, with the same result

### AC-08 (US-02) — domain invariant
**Given** a set whose page says it has 120 cards
**When** the app reads fewer cards than that
**Then** the results dialog says how many of how many were read ("Read 90 of 120 cards"), so the learner never gets a shortened set without being told ("a set is read whole or the gap is named")

### AC-09 (US-02) — domain invariant
**Given** a set with a card that has no text term (an image-only card), and a card whose back side spans several lines and is longer than the longest translation a shared page accepts
**When** the learner imports it
**Then** the image-only card is not proposed, and the long back side is shown on one line and cut to that length ending in "…" (§6), so every kept word can be published ("every imported word is a publishable word")

### AC-10 (US-02) — domain invariant
**Given** the current session already holds "reluctant", and the set has "Reluctant" once and "deadline" twice
**When** the learner imports the set
**Then** "Reluctant" is not proposed and "deadline" is proposed once ("no word enters a session twice through an import"), matching the subtitle import

### AC-11 (US-01) — authorization
**Given** the set's page is open inside the app
**When** the page tries to take the learner to a page that is not on Quizlet (an advert, a store page, another site), or the learner taps such a link
**Then** that page is not opened inside the app and no words are ever read from it, so only Quizlet set pages can put words into a session

### AC-12 (US-05) — authorization
**Given** a learner publishes a session with one source photo and one set source, with "Include sources" switched off
**When** a partner opens the shared page
**Then** the page shows no source pager, no photo button and no highlighted rows, and nothing on it reveals the set's name or link

### AC-13 (US-04) — cross-context
**Given** a session with two source photos and one set source was published with "Include sources" on, and a partner opens it on a wide screen
**When** the partner moves the pager to the set source
**Then** the pager shows the set's name with its Quizlet link under it and the position ("3 of 3"), the rows imported from that set are highlighted and the others are not, and choosing the link opens the set on Quizlet in a new tab

### AC-14 (US-04) — cross-context
**Given** the same session and a partner on a phone
**When** the partner opens the sources from the stacked-thumbnail button
**Then** the swipeable dialog has a page for the set source showing its name and link, alongside the photos

### AC-15 (US-05) — cross-context
**Given** a learner opens Share on the Words screen for a session with two source photos and one set source
**When** the share sheet shows
**Then** the switch reads "Include sources (3)", is on by default, and says that included sources are visible to anyone with the link for 30 days; a set none of whose words remain in the session is not counted and not published

### AC-16 (US-02) — cross-context
**Given** a Quizlet import is running
**When** the current session is no longer the one the import started in by the time the results dialog would open
**Then** the words are dropped and neither session changes (the late-result rule of the photo and subtitle imports)

### AC-17 (US-06) — cross-context
**Given** words from a Quizlet set were added to the current session
**When** the learner opens the words table, opens the session from History, or exports it to AnkiDroid
**Then** those words appear like other words, with the card's back side as their translation, and the app does not replace that translation with its own

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Time from starting the import to the results dialog, public 100-card set, Wi-Fi, no robot check | p95 ≤ 10 s | on the phone, 5 runs on each of 3 sets |
| Cards read | 100% of text cards for sets of up to 500 cards | device pass: sets of 10, 50, 200 and 500 cards; the dialog count equals the set's own count |
| Back side length | ≤ 500 characters per translation (AC-09) | automated check on the proposed words before the dialog opens |
| Sources per published session | no limit (owner decision 2026-10-06): every source photo and set source with a remaining word row is published | publish test with 12 photos and 3 sets: the pager shows all 15 |
| New device permissions | 0 | fresh install on iPhone and Android: no new permission prompt |

## 6.1 Security / privacy

- **Data classification:** internal. A Quizlet set link and name are public on Quizlet already; once published they are visible to anyone with the shared link for 30 days.
- **Personal data touched:** none new. The set's name and link are stored with the session on the device and, with "Include sources" on, published.
- **AuthZ/AuthN impact:** no new capability on the server's side beyond accepting set sources (name and link) when a session is published, checked the same way as today's publish. The in-app page opens only Quizlet pages (AC-11) and the learner is never asked to log in there.
- **Abuse cases:**
  - Made-up words from a non-Quizlet page (a pasted link to another site, or a redirect): the import refuses non-Quizlet links (AC-06) and never reads a page that is not on Quizlet (AC-11).
  - A hostile set name or link on the shared page (script or markup in the name, a link that is not Quizlet): the shared page shows the name as plain text and only accepts a Quizlet set link as a set source.
  - Many sources on one shared page (no source limit, owner decision): set sources are only a name and a link; source photos stay behind "Include sources" and their existing size limit per photo.
  - A huge set flooding the session (no card limit, owner decision): the learner sees the count in the dialog before Done; a session over the existing 500-row limit cannot be published, as today.
  - Quizlet's terms of use and bot protection: reading set pages may be against Quizlet's terms and can be blocked at any time; the import then fails with the AC-07 message and nothing else breaks (§8 OQ-1).
- **Security review:** Required — a web page from a third party is opened and read inside the app, and the published session gains a new kind of field shown on a public page.

## 7. Metrics / KPIs

<!-- N/A: owner decision 2026-10-06 — no KPIs are tracked for this feature (a one-owner app with no analytics); the §6 targets and the device pass are the check. -->

## 8. Open questions

- [ ] OQ-1: Do Quizlet's terms of use allow reading a public set's page inside the app for the learner's own study? Default now: proceed for personal use and accept that Quizlet may block it. — owner: Maksym, due: before `sdd:design`
