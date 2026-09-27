---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-09-27"
feature_size: "M"
---

# Spec — good-looking-web

> **Glossary:** [CONTEXT](./CONTEXT.md) · [project CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** [`docs/roadmap.md`](../../roadmap.md) (step 6, D4, D6, out-of-scope list) · [`docs/tasks/outdated/task-06-partner-corrects-table.md`](../../tasks/outdated/task-06-partner-corrects-table.md) (the earlier plan for editing on the shared page) · [`docs/features/definition-mode/spec.md`](../definition-mode/spec.md) (word detail mode, dictionary allowance) · the current shared page in `vocab-photo-api/src/session/`

## 1. Context

The shared page is the only place a partner sees the learner's words, and today it is the weakest surface of the product. The table is squeezed into a narrow centre column with wide empty margins on both sides. Every column shares the same narrow width, so a long definition stretches its row into a tall block while short words leave empty space. There is no way to see which page of the book a word came from. The partner can only read: a wrong translation, a typo, or a word the learner missed cannot be fixed or added, and a missing translation or definition has to be typed from memory. This affects the partner (one or two people at the learner's table) and, through the AnkiDroid file downloaded from the page, the learner.

Why now: definition-mode (2026-09-27) put long English definitions onto the shared page, and the narrow table now visibly fails them. The published session format already reserves a place for photos, but the app has never sent one, so the "where did this word come from" link the product was designed around is still missing. The owner asked for the page to become a working tool at the table rather than a read-only printout (owner request, 2026-09-27).

Committed approach: turn the shared page into a spreadsheet-like word table whose columns take the space their content needs, each up to its own maximum width, and that anyone holding the link can edit. It has two layouts. A **wide layout** shows the table with the session's source photos in a pager in the right corner and highlights the rows that came from the photo on display. A **phone layout** shows a horizontally and vertically scrollable table with fixed maximum column widths, and puts the photos behind a small stacked-thumbnail button that opens them in a swipeable dialog. Every translation and definition cell has its own lightning for autofill, and each of those two columns has a lightning that fills all its empty cells. Definition autofill is bounded by a per-page autofill allowance, so a forwarded link cannot starve the app's own lookups; translation autofill costs no dictionary quota and is not metered. Edits live only on the shared page and in the file downloaded from it. Grounding: no adjacent product combines a no-login, time-limited link with an editable spreadsheet-style table and source images linked to their words (competitive research 2026-09-27: Quizlet has editing but needs accounts; link-only deck viewers are read-only; Readlang links words to text but not across several photos). The sharpest failure vector found is autofill on a public page using up the dictionary quota that the app's own lightning depends on, and that is why the allowance is part of the scope.

- Decision: the shared page shows every column that holds data, whatever word detail mode the learner published with. A column where every cell is empty collapses and can be added back. This revises, for the shared page only, definition-mode ADR-0004 (the page picks its columns from the published mode): the option ADR-0004 rejected, "the page infers columns from the data", is now chosen for the page.
- Decision: the file downloaded from the shared page keeps definition-mode ADR-0005's fixed column places (word, translation, definition, tags); a collapsed column is written empty in its place, so the file imports into the same note type as the app's own export. It carries the page's data, so for the same session it can differ from the learner's own export — definition-mode AC-20 ("the same fixed places as the learner's own export") still holds for the places, not the content.
- Decision: a column-wide "fill all empty cells" autofill is in scope, although definition-mode made "fill all definitions" a non-goal to protect the dictionary's daily allowance (its open question on this is still open). Rationale: here the per-page autofill allowance and the app's reserved share of the quota (AC-29) bound it; definition-mode's non-goal stays in force for the app.
- Decision: the shared page shows several source photos, superseding roadmap D5 ("one photo per session in v1"). D5 already stored the photos as a list, so this is the addition D5 anticipated.
- Decision override: size kept at M despite absorbing roadmap step 6 (itself sized M) and adding app-side photo keeping — rationale: single-owner app, one deploy; accepted risk: less explicit design for the photo-publishing half unless `design` gives it its own ADRs.
- Decision override: product names AnkiDroid, Quizlet, Readlang and Reverso stay in §1–§3 — rationale: AnkiDroid is the export destination named in the idea brief's goal, the others are competitive grounding or history, not technology choices.
- Decision: roadmap step 6 ("the partner corrects the word table") is absorbed here. The "no sync-back" rule and D6 (no per-visitor names) stay in force.
- Decision: source photos are published only when the learner leaves "include photos" switched on at publishing time. D4 (30-day life, no delete) still applies to them.

## 2. Goals

- A partner can read the whole word list comfortably on the device they have at hand, whether a phone in portrait or a laptop, without the table being squeezed into a narrow column.
- The partner can see which source photo a word came from and can correct, add and remove words on the shared page, so the list that reaches AnkiDroid is the corrected one.
- Filling a missing translation or definition on the shared page takes one tap, and it never costs the learner their own lightning in the app.

## 3. Non-goals

- Edits on the shared page flowing back into the app. The roadmap closes this direction; the downloaded file is the only return path.
- Live, as-you-type collaboration where other people's keystrokes appear instantly. Two or three people at one table need edits that do not get lost, not a real-time editor.
- Adding words from a new photo on the shared page. The page adds rows by typing only; photo recognition stays in the app.
- Deleting a published photo or session before its 30 days are up. D4 stands; the learner's protection is the choice not to publish photos.
- Highlighting the rows of the current photo on a phone. The phone layout shows photos in a dialog, where there is no table beside them to highlight.
- Per-visitor names or edit history. D6 stands; nothing on the page depends on who made an edit.

## 4. User stories

### US-01: Read the list on a wide screen
**As a** partner
**I want** the word table to use the width of a laptop or tablet screen beside the photos, with a typical word and translation on one line, longer ones wrapped, and definitions in full at a readable width
**So that** I can scan the whole list without the table squeezed into a narrow strip

### US-02: Read the list on a phone
**As a** partner
**I want** a phone layout with a narrow row-number column, Word and Translation columns that fit on screen, and a Definition column I can scroll to
**So that** the list stays readable on a phone held in portrait

### US-03: See where words came from on a wide screen
**As a** partner
**I want** the session's source photos in a pager in the right corner, with the rows from the current photo highlighted
**So that** I can see each word in the context of the page it was taken from

### US-04: Look at the photos on a phone
**As a** partner
**I want** a small stacked-thumbnail button that opens the source photos in a swipeable dialog
**So that** I can check the book page without the photos taking up the table's space

### US-05: Correct a cell
**As a** partner
**I want** to edit a word, translation or definition directly in the table
**So that** a typo or a wrong translation is fixed before the list goes into AnkiDroid

### US-06: Add a word
**As a** partner
**I want** a plus button that adds one empty row to the table
**So that** a word the learner missed can go into the list

### US-07: Remove a word, with undo
**As a** partner
**I want** to delete a row and undo it for a few seconds afterwards
**So that** unwanted words leave the list and a wrong tap does not lose one

### US-08: Autofill one cell
**As a** partner
**I want** a lightning in a translation or definition cell that fills that cell
**So that** I don't have to type translations and definitions myself

### US-09: Autofill a whole column
**As a** partner
**I want** a lightning in the Translation or Definition column header that fills every empty cell of that column
**So that** a list with many gaps is completed in one tap

### US-10: Bring back a missing column
**As a** partner
**I want** to add the Translation or Definition column when the list was published without it
**So that** I can add the kind of detail the learner did not collect

### US-11: Choose whether photos are published
**As a** learner
**I want** an "include photos" switch when I publish a session
**So that** a photo with something private on it does not become public for a month

### US-12: Photo words keep their photo
**As a** learner
**I want** the app to keep each photo I take in a session, together with the words recognised from it
**So that** the shared page can show which words came from which page

### US-13: Download what I see
**As a** partner
**I want** the AnkiDroid file downloaded from the shared page to contain the columns and rows the page shows, including every edit
**So that** the cards match the corrected list

## 5. Acceptance criteria

### AC-01 (US-01) — happy
**Given** a partner opens a shared page on a wide screen
**When** the page loads
**Then** the table sits beside the photo area and is no wider than the space left by it; the row-number column is only as wide as its numbers; Word and Translation each have a maximum width wide enough that a typical word or translation fits on one line; the Definition column has a maximum width taken from the screen size and shows each definition in full, over as many lines as it needs

### AC-02 (US-01) — domain invariant
**Given** a word, translation or definition is longer than its column's maximum width
**When** the partner views the table on any screen
**Then** the text wraps inside its cell and the row grows taller; no column grows beyond its maximum width, no text is cut short, and a definition keeps its line break between the definition and the example

### AC-03 (US-02) — happy
**Given** a partner opens a shared page on a phone held in portrait
**When** the page loads
**Then** the table shows a narrow row-number column, then Word and Translation each at a fixed maximum width that together fill less than the screen width, then the start of the Definition column; the table scrolls sideways and downwards, and the rest of the page does not scroll sideways

### AC-04 (US-02) — happy
**Given** a definition is longer than the Definition column's maximum width
**When** the partner views it in the phone layout
**Then** the definition shows in full, wrapped over as many lines as it needs within the column's maximum width, so a long definition makes its row taller, never the table wider

### AC-05 (US-03) — happy
**Given** a session was published with three source photos and a partner opens it on a wide screen
**When** the partner swipes the photo pager in the right corner to the second photo
**Then** the pager shows the second photo with its position ("2 of 3"), and the rows recognised from that photo are highlighted while the other rows are not; the pager stays in view in its corner while the table scrolls, and if none of the highlighted rows is visible, the table scrolls to the first of them

### AC-06 (US-03) — domain invariant
**Given** a row was typed by the learner or added on the shared page
**When** any photo is on display in the pager
**Then** that row is never highlighted, because it has no source photo

### AC-07 (US-04) — happy
**Given** a session has several source photos and a partner opens it on a phone
**When** the partner taps the stacked-thumbnail button
**Then** a dialog opens with the first photo filling the screen width, the partner can swipe between all photos and zoom into one, and closing the dialog returns to the table at the same scroll position

### AC-08 (US-04) — happy
**Given** a session has exactly one source photo
**When** a partner views it on a phone
**Then** the photo button shows a single thumbnail, not a stack; a session with no source photos shows no photo button and, on a wide screen, no photo area

### AC-09 (US-05) — happy
**Given** a partner is viewing a shared page
**When** they change the translation of a row and leave the cell
**Then** the change is saved, the cell shows a brief "saved" confirmation, and anyone who reloads the page or downloads the file sees the new translation

### AC-10 (US-05) — error
**Given** a partner types into a cell
**When** the text goes over the field's length limit
**Then** the cell is not saved; the typed text stays in the cell, marked as not saved, so it can be shortened without being lost; the partner is told in plain words that the word, translation or definition is too long and by how much, and every other cell of the table stays saved

### AC-11 (US-05) — domain invariant (concurrent edit)
**Given** two partners have the same shared page open and both change the translation of the same row
**When** the second partner saves after the first one's change was saved
**Then** the second partner's cell shows both values, theirs and the one saved in the meantime, and asks which one to keep; neither value disappears without someone choosing

### AC-12 (US-05) — domain invariant (concurrent edit)
**Given** two partners have the same shared page open
**When** one changes the word of one row and the other changes the definition of a different row
**Then** both changes are kept, and each partner's page shows the other's saved change within 10 seconds without reloading while that page is in use (an idle page catches up on its next interaction — revised at design 2026-09-27); a saved change arriving for a cell that partner is still typing in does not overwrite it — it surfaces as the choice in AC-11 when they save

### AC-13 (US-06) — happy
**Given** a partner is viewing a shared page
**When** they tap the plus button
**Then** one empty row is added at the end of the table with the cursor in its Word cell, and it is saved once any of its cells holds text; a row that never received text is gone after a reload

### AC-14 (US-06) — domain invariant
**Given** a shared page already holds the maximum number of rows a session may have
**When** a partner taps the plus button
**Then** no row is added, and the page says the list is full and names the limit

### AC-15 (US-07) — happy
**Given** a partner is viewing a shared page
**When** they delete a row
**Then** the row leaves their table and an "Undo" option shows for 5 seconds; choosing it puts the row back in the same place with its source photo. The delete takes effect for everyone only when the 5 seconds end without Undo; closing the page before then leaves the row in place

### AC-15b (US-07) — domain invariant (concurrent edit)
**Given** a partner deleted a row and its 5-second Undo is still running
**When** another partner saves a change to that same row in those seconds
**Then** the delete is not applied, the row stays with the other partner's change, and the partner who deleted it is told the row was changed meanwhile, so no edit disappears silently

### AC-16 (US-08) — happy
**Given** a row has a word and an empty definition
**When** the partner taps the lightning in that row's Definition cell
**Then** the cell fills with a definition for the word, the lightning shows it is working until then, and only that cell changes

### AC-17 (US-08) — error
**Given** a row's word has no translation or no definition to be found (a misspelling, or a word the source doesn't know)
**When** the partner taps that cell's lightning
**Then** the cell stays empty and the page says, next to it, that nothing was found for this word, so the partner can type the value or fix the spelling

### AC-18 (US-08) — domain invariant
**Given** the shared page's autofill allowance for today is used up
**When** a partner taps a definition lightning
**Then** nothing is filled, and the page explains that definition autofill is paused, names the local time it resumes (the start of the next day in universal time), and says the cell can still be typed by hand; translation lightnings keep working

### AC-18b (US-08) — cross-context
**Given** all shared pages together have used their share of today's dictionary quota, while this page still has allowance left
**When** a partner taps a definition lightning
**Then** the page shows the same "definition autofill is paused" explanation and resume time as in AC-18, not "nothing found" and not a generic error

### AC-19 (US-09) — happy
**Given** the Definition column has 8 empty cells and 4 filled ones, and the allowance covers all 8
**When** the partner taps the lightning in the Definition column header
**Then** the 8 empty cells are filled one by one, the 4 filled cells stay exactly as they were, and the page reports how many cells were filled and how many found nothing

### AC-20 (US-09) — domain invariant
**Given** the Definition column has 8 empty cells and the allowance left today covers only 5 lookups
**When** the partner taps the column's lightning
**Then** the first 5 empty cells in table order are looked up, each lookup using one unit of the allowance whether or not it finds a definition; the other 3 stay empty, and the page says the allowance ran out after 5 lookups and how many of them found nothing

### AC-21 (US-10) — happy
**Given** a session was published with translations only, so every definition cell is empty
**When** a partner opens the shared page
**Then** the Definition column is collapsed to a narrow "add Definition" control; tapping it opens the column with empty cells and their lightnings. Opening it is local to that partner's page: other partners see the column once any of its cells holds text, and a column that is still empty collapses again on reload

### AC-22 (US-10) — happy
**Given** a session was published with both translations and definitions filled
**When** a partner opens the shared page
**Then** Word, Translation and Definition all show, whatever word detail mode the learner had on the device

### AC-23 (US-11) — happy
**Given** a learner publishes a session that has source photos
**When** the share sheet offers the link
**Then** it shows an "include photos" switch with the number of source photos (photos with at least one word row linked at publishing time), switched on by default, and states that included photos are visible to anyone with the link for 30 days

### AC-24 (US-11) — authorization
**Given** a learner published a session with "include photos" switched off
**When** anyone opens the shared page, including by guessing where a photo would be
**Then** no source photo of that session can be seen, and the page shows no photo button or photo area, as if the session had no photos

### AC-25 (US-12) — cross-context
**Given** a learner took two photos in a session, and some rows were recognised from each while others were typed
**When** the learner publishes the session with photos included
**Then** the shared page shows both photos, and each recognised row is linked to the photo it came from while the typed rows are linked to none

### AC-26 (US-12) — cross-context
**Given** a session was collected before this feature, so the app kept no photos for it
**When** the learner publishes it
**Then** the shared page shows the table with no photo button and no photo area, and publishing does not fail

### AC-27 (US-12) — cross-context
**Given** a learner publishes a session whose app mode shows translations only, while some rows also hold a stored definition
**When** a partner opens the shared page
**Then** the stored definitions are there on the page, because the app publishes every stored translation and definition and the page decides which columns to show

### AC-28 (US-05) — cross-context
**Given** a partner corrected and added words on the shared page
**When** the learner opens the same session in the app
**Then** the app's session is unchanged; the page's edits reach the learner only through the file downloaded from the shared page

### AC-29 (US-08) — cross-context
**Given** shared pages together have used as many autofills today as all shared pages are allowed
**When** the learner taps a lightning in the app
**Then** the app's lightning still works, because shared pages can never use the part of the daily dictionary quota kept for the app

### AC-30 (US-13) — happy
**Given** the shared page shows Word, Translation and Definition, with edits made on the page
**When** a partner downloads the AnkiDroid file
**Then** the file holds the rows exactly as saved on the page, with word, translation and definition in their fixed places; a column that is collapsed on the page is written empty in its place

### AC-31 (US-13) — domain invariant
**Given** a partner cleared every cell of a row without deleting it, and another row has a translation but an empty word
**When** anyone downloads the file
**Then** neither row is in the file, because the file is built from what is saved and a card needs a word; the page marks a row with an empty word as "not in the download — needs a word"

### AC-32 (US-05) — authorization
**Given** a shared page has passed its 30 days, or the link is mistyped
**When** anyone opens it
**Then** they see the "this word list is gone" page, with no table, no photos and nothing to edit, and the page does not reveal whether the list ever existed

### AC-33 (US-05) — error
**Given** a partner types markup or a script into a word cell (for example angle-bracket tags)
**When** the cell is saved and anyone views the page or downloads the file
**Then** the text is shown exactly as typed, as plain text, and nothing in it runs or changes the page

### AC-34 (US-05) — domain invariant
**Given** a row was recognised from a source photo
**When** a partner corrects its word or translation on the shared page
**Then** the row stays linked to its source photo and is still highlighted when that photo is on display

### AC-35 (US-09) — domain invariant
**Given** two partners edit the same shared page for 15 minutes, saving cells and using a column autofill once
**When** they keep working at a normal pace
**Then** no save or autofill is turned away for being too frequent

### AC-36 (US-02) — happy
**Given** a partner is typing in a cell on a phone
**When** they turn the phone to landscape, or resize a laptop window across the layout boundary
**Then** the page switches between the phone and the wide layout by the width of the screen alone, at once, without reloading and without losing the text being typed

### AC-37 (US-12) — cross-context
**Given** a learner publishes a session with three source photos included, on a slow connection
**When** they tap publish
**Then** the dialog with the link opens as soon as the word list is published, without waiting for the photos; the photos upload in the background, retried several times, without blocking the app; a photo that never arrives shows on the shared page as an empty placeholder in its place in the pager, and its rows stay linked to that placeholder

### AC-38 (US-06) — domain invariant
**Given** a shared page's list is close to the most text a session may hold
**When** a partner saves an edit or a new row that would take it over that size
**Then** the edit is not saved, stays in its cell marked as not saved, and the page says the list is full

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Shared page first render p95, 100 rows, phone on 4G | ≤ 2.0 s to a readable table | Lighthouse mobile profile run against a 100-row session before release |
| Cell save p95 (edit leaves the cell → "saved" shown) | ≤ 1.0 s | Worker request timing for the save action, from Cloudflare analytics |
| Single-cell autofill p95 | ≤ 3.0 s | Worker request timing for the autofill action |
| Definition autofill allowance per shared page per day | 50 definition lookups (every lookup counts, found or not; a column autofill counts one per cell looked up; translation autofill is not metered) | Worker counter per session per UTC day; spec §8 OQ-2 confirms the number |
| Share of daily dictionary quota kept for the app | ≥ 50% — all shared pages together stop at 500 of the 1,000 daily calls | Worker counter across all sessions per UTC day |
| Lost edits under concurrent editing | 0 — every save either lands or comes back as a conflict the partner resolves | Concurrency test: 3 clients edit the same and different cells of one session 100 times |
| Phone layout width | No page-level sideways scroll at 360 px viewport width; only the table scrolls sideways | Visual check at 360, 390 and 414 px |
| Photos per published session | ≤ 10 (today's limit on a published session) | Publish test with 11 source photos: the page shows 10 and the app names the one left out (spec §8 OQ-3) |
| Publish with photos, 3 photos on 4G | Link dialog p95 ≤ 3 s after tap, whatever the photos do; all 3 photos on the page p95 ≤ 30 s in the background | Manual timing on device, 10 runs |
| Other partners' saved edits appearing on an open page | ≤ 10 s, without reload, while the page is in use (revised at design 2026-09-27: after 5 minutes without interaction the page pauses updates and catches up on the next interaction — sad §6) | Two browsers on one session, 20 edits timed |
| Session content limits (unchanged from today) | ≤ 500 rows, ≤ 500 characters per field, ≤ 256 KB per session | Worker validation tests at each limit + 1 |

## 6.1 Security / privacy

- **Data classification:** internal. A word list is low-sensitivity, but source photos can incidentally show private content (faces, addresses, letters) and are public to anyone holding the link for 30 days.
- **Personal data touched:** source photos (image, possibly containing incidental personal data). They are published only with the learner's explicit "include photos" switch on. No new identity fields: D6 stands and edits are anonymous.
- **AuthZ/AuthN impact:** the link remains the only credential, now for writing as well as reading. Any holder of a valid, unexpired link can edit, add, delete and autofill. An expired or unknown link grants nothing and hides whether the list existed. Photos of a session published without photos must not be reachable at all.
- **Abuse cases:**
  - Forwarded link used to vandalise the list: accepted in v1 (link = credential). Undo covers a wrong tap, not a malicious holder. The learner's own copy in the app is never touched, so republishing restores the list — today as a new link, while the vandalised one lives out its 30 days; whether republishing should overwrite the same link is §8 OQ-4.
  - Forwarded link used to drain the dictionary quota: the per-page autofill allowance plus the app's reserved share of the quota (AC-18, AC-20, AC-29).
  - Injection through a cell (markup or script typed into a word): every value is shown as text, never as markup, on the page and in the downloaded file.
  - Spam-writing (a script filling the list, or making it a free text host): the row limit per session (500, AC-14), the field length limit (500 characters, AC-10), the session size limit (256 KB, AC-38), and a per-visitor write rate limit, sized in design.
  - Private photo exposure: the "include photos" switch (AC-23, AC-24). D4's no-delete stays an accepted risk (§8 OQ-4).
- **Security review:** Required. This adds a new public write surface and publishes user photos.

## 7. Metrics / KPIs

- **Share of published sessions edited on the shared page** (≥1 saved edit, add or delete) — baseline: 0 (editing does not exist), target: ≥ 30% of sessions published within 60 days of release. Measured by a Worker count of sessions with at least one write.
- **Share of publishes that include photos** (of sessions that have source photos) — baseline: 0 (the app sends none), target: ≥ 60% within 60 days.
- **Days on which the app's lightning failed because the dictionary quota ran out** — baseline: 0, target: stays 0 through 60 days after release. Measured from the Worker's dictionary-unavailable log lines.
- **Share of shared-page autofills that fill a value** (vs "nothing found") — baseline: TBD, measured by the Worker from the first week after release; target: ≥ 85%.

## 8. Open questions

- [ ] OQ-1: Where does a translation autofill on the shared page come from, given translation runs only on the phone today and a server-side call to the free service may be blocked like Reverso was? Default now: the free machine-translation service called from the partner's browser, so it costs no server quota and is outside the autofill allowance (resolved at clarify 2026-09-27); if design routes it through the server, it gets its own limit. — owner: Maksym (Tech Lead), due: before `sdd:design`
- [ ] OQ-2: Are 50 autofills per shared page per day, and 500 of the 1,000 daily dictionary calls for all pages together, the right numbers? Default now: 50 and 500. — owner: Maksym, due: before `sdd:design`
- [ ] OQ-3: A published session holds at most 10 source photos today, while the app may keep more. Which photos go when a session has more than 10? Default now: the first 10 taken, and the app tells the learner the rest were left out. — owner: Maksym, due: before `sdd:design`
- [ ] OQ-4: With photos public for 30 days and no delete (D4), is the "include photos" switch enough protection, or does v1 need a way to take a published session down? And should republishing a session overwrite its existing link (the owner's preference at clarify 2026-09-27, which also erases the partners' page edits and needs the app to remember the link) instead of creating a new one? Default now: the switch is enough; republishing overwrites the same link; takedown stays out of scope. — owner: Maksym (Security Lead), due: before `sdd:tasks`
- [ ] OQ-5: At what screen width does the page switch between the phone and the wide layout (AC-36), and what are the exact maximum widths of the Word, Translation and Definition columns on each layout? The owner wants to see them before deciding. Default now: Word and Translation fit a typical entry on one line; Definition takes the width left beside the photo area, capped at a readable line length. — owner: Maksym, due: at `sdd:screens`
