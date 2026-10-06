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

Committed approach: a new "Import from Quizlet" item takes the Screenshot item's place in the red + menu, with the same green colour, and Screenshot is removed. It opens a dialog for a Quizlet set link. The app opens the set's page inside the app, behind a progress dialog with a small live preview of the page, and reads the set's name and cards from the page itself on the phone, with no server step and no AI. Each card's term becomes the English word; its back side, followed on a new line by the card's example sentence when it has one, becomes the definition; and the app fills the translation the way it does for a typed word. The cards open in the same results dialog as a photo or subtitle import, and Done appends the kept words to the current session. Each kept word remembers the set as its source, so on the shared page the set appears in the source pager next to the photos, as the set's name and its link, with its rows highlighted like a photo's. Grounding: the tools compared (Quizlet-to-Anki add-on, the quizlet-fetcher parser, Knowt and other browser extensions, Quizlet's own Export) all work either from a desktop browser that has already passed Quizlet's robot check or from an owner-only export; none imports a set from a link on a phone (research 2026-10-06). A plain automated read of the owner's link is refused with a robot check, which is why the page is opened inside the app where the learner can pass that check. The sharpest failure found was the card's back side not being a Ukrainian translation (the owner's example set has English explanations); putting the back side in the definition and translating the term resolves it, and AC-09 keeps long text from breaking publishing.

- Decision (owner, 2026-10-06): the Screenshot item, its capture code and the `screenshot` package are removed; CLAUDE.md rule 3 is updated to stop listing `screenshot` (rule 5 approval given).
- Decision (owner, 2026-10-06): one new app package for showing a web page inside the app is approved (CLAUDE.md rule 5); which one is chosen in `design`.
- Decision (owner, clarify 2026-10-06): the card's back side, plus its example sentence on a new line when there is one, goes into the definition; the translation is filled by the app's usual automatic translation of the term. This replaces the earlier "back side → translation" decision.
- Decision (owner, clarify 2026-10-06): the import does no dictionary or AI lookup; a definition taken from a card counts as filled, like an automatic one, so no lightning invites replacing it.
- Decision (owner, clarify 2026-10-06): the in-app page opens only Quizlet's own pages, strictly; a robot check served from anywhere else cannot load, and the import then ends as a failure (AC-07).
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
- Translating a card's back side — it is kept in English as the definition; only the term is translated (§1 decision).
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
**Given** a learner in the Quizlet dialog has pasted text holding a link to a public set of 40 cards — the bare link, with or without its web prefix, with a language part, with the sharing extras Quizlet adds at the end, a link to one of the set's study modes, or the link inside Quizlet's own share text ("Check out this set: …")
**When** the learner starts the import
**Then** a progress dialog shows "Reading the Quizlet set…", the set's name as soon as it is known, and a small live preview of the set's page, so the learner can see it is the right set; once the cards are read the progress dialog closes by itself and the results dialog opens with the set's name at the top and all 40 cards in set order, each showing the card's term as the word, a translation of the term made the way a typed word is translated, and the card's back side as the definition, followed on a new line by the card's example sentence when it has one

### AC-03 (US-02) — happy
**Given** the results dialog shows 40 cards from a set
**When** the learner removes 3 of them and taps Done
**Then** the 37 kept words are added at the end of the current session on the main screen in set order, each remembering the set as its source, and the 3 removed words are not added

### AC-04 (US-02) — happy
**Given** the results dialog for a set is open
**When** the learner removes every word and taps Done, or closes the dialog without Done
**Then** the current session is unchanged and the set is not a source of the session

### AC-04b (US-02) — happy
**Given** every card of a set is skipped, because each is already in the current session, repeats an earlier card or has no text term
**When** the learner imports the set
**Then** the results dialog opens with the set's name, says "No new words in this set." with the line naming how many cards were skipped, and Done leaves the session unchanged and adds no set source

### AC-05 (US-01) — happy
**Given** Quizlet shows its "I'm not a robot" check on one of its own pages while the set is being read
**When** the check appears
**Then** the preview grows to full size so the learner can pass the check, shrinks back once it is passed, and the import reaches the results dialog without the learner pasting the link again; a check served from outside Quizlet does not load and the import ends as in AC-07

### AC-06 (US-03) — error
**Given** a learner in the Quizlet dialog
**When** the learner starts an import with text that holds no link to a Quizlet set (only a link to another site, a link to a Quizlet folder or class, or plain words)
**Then** the import does not start and the dialog says to paste a link to a Quizlet set, keeping the text so it can be fixed

### AC-07 (US-03) — error
**Given** an import is running
**When** there is no connection, the page does not load, or no cards are found within 30 seconds after the page has loaded (a private or deleted set, a login wall, a robot check from outside Quizlet, or a Quizlet page the app no longer understands); the 30 seconds do not run while Quizlet's own robot check is on screen
**Then** no words are proposed, the learner is back on the main screen with the current session unchanged, and the app says the cards of this set couldn't be read and they can try again

### AC-07b (US-03) — happy
**Given** the progress dialog of an import is showing, before the results dialog opens
**When** the learner taps Cancel or goes Back
**Then** the import stops, the learner is back on the main screen with the current session unchanged, and no message is shown

### AC-08 (US-02) — domain invariant
**Given** a set whose page says it has 120 cards
**When** the app finds fewer cards than that on the page, counted before any card is skipped
**Then** the results dialog says how many of how many were found ("Read 90 of 120 cards"), so the learner never gets a shortened set without being told ("a set is read whole or the gap is named"); cards skipped on purpose (AC-09, AC-10) do not make this line appear but are named in their own line ("3 cards skipped: already in the session, repeated or without text"); when the page states no count, no "of" line is shown

### AC-09 (US-02) — domain invariant
**Given** a set with a card that has no text term (an image-only card), a card with a term but no text on its back, and a card whose term or back side spans several lines and is longer than the longest text a shared page accepts in one field
**When** the learner imports it
**Then** the image-only card is not proposed; the card without a back is proposed with the translation the app makes and an empty definition; and in every term and back side line breaks become "; " and text over the length limit is cut to it, the last character being "…", the cut text being what is kept, so every kept word can be published ("every imported word is a publishable word")

### AC-10 (US-02) — domain invariant
**Given** the current session already holds "reluctant", and the set has "Reluctant." once and "deadline" twice with different backs
**When** the learner imports the set
**Then** "Reluctant." is not proposed and "deadline" is proposed once, with the back of its first card in set order ("no word enters a session twice through an import"); two words are the same when they are equal after ignoring capital letters, spaces at either end and one closing ".", "!" or "?"

### AC-11 (US-01) — authorization
**Given** the set's page is open inside the app
**When** the page tries to take the learner to a page that is not one of Quizlet's own (an advert, a store page, another site, a check served from another company), or the learner taps such a link, or the learner moves to a different Quizlet set
**Then** a page that is not Quizlet's own is never opened inside the app, and words are read only from the set whose link was pasted, so nothing else can put words into a session

### AC-12 (US-05) — authorization
**Given** a learner publishes a session with one source photo and one set source, with "Include sources" switched off
**When** a partner opens the shared page
**Then** the page shows no source pager, no photo button and no highlighted rows, and nothing on it reveals the set's name or link

### AC-13 (US-04) — cross-context
**Given** a session with two source photos and one set source was published with "Include sources" on, and a partner opens it on a wide screen
**When** the partner moves the pager to the set source
**Then** the pager shows the set's name with its Quizlet link under it and the position ("3 of 3"), the rows imported from that set are highlighted and the others are not, and choosing the link opens the set on Quizlet in a new tab; the link is the set's plain address, without a language part or the sharing extras of the pasted link

### AC-13b (US-04) — domain invariant
**Given** a learner imported a set, and later imports the same set again from a different link shape after it was renamed on Quizlet
**When** the learner keeps new words from the second import
**Then** the session still has one set source for that set ("one set, one source"), its new words are linked to it, and it shows the newer name; "Include sources" counts it once

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
**Then** those words appear like other words, with the app's translation and the card's back side (and example) as their definition, and neither field shows a lightning inviting the learner to replace it; a word whose card had no back shows the definition lightning as a typed word would

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Time from starting the import to the results dialog, public 100-card set, Wi-Fi, no robot check, translations included | p95 ≤ 10 s | on the phone, 5 runs on each of 3 sets |
| Wait for cards after the page has loaded | 30 s, then the AC-07 message; paused while Quizlet's robot check is on screen | device pass: a set link whose page shows no cards ends with the AC-07 message 30 ± 2 s after loading |
| Cards found | 100% of the set's cards for sets of up to 500 cards | device pass: sets of 10, 50, 200 and 500 cards; no "Read X of Y" line appears |
| Field length | ≤ 500 characters per word and per definition, the "…" included (AC-09) | automated check on the proposed words before the results dialog opens |
| Sources per published session | no limit (owner decision 2026-10-06): every source photo and set source with a remaining word row is published | publish test with 12 photos and 3 sets: the pager shows all 15 |
| New device permissions | 0 | fresh install on iPhone and Android: no new permission prompt |

## 6.1 Security / privacy

- **Data classification:** internal. A Quizlet set link and name are public on Quizlet already; once published they are visible to anyone with the shared link for 30 days.
- **Personal data touched:** none new. The pasted link's sharing extras, which may point back to the learner's Quizlet account, are never stored or published (AC-13). The set's name and plain link are stored with the session on the device and, with "Include sources" on, published.
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

- [x] OQ-1: Do Quizlet's terms of use allow reading a public set's page inside the app for the learner's own study? Resolved (owner, design 2026-10-06): accepted risk — proceed for personal study and accept that Quizlet may block it; a block ends as AC-07 (sad §11). — owner: Maksym, due: before `sdd:design`
