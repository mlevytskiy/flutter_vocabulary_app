---
status: Reviewed
owner: "Maksym (learner, app owner); decisions delegated to a Fable 5.1 owner proxy, 2026-10-16"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-16"
feature_size: "L"
---

# Spec — collection-tags

> **Glossary:** [project CONTEXT](../../../CONTEXT.md) (origin tag, topic tag, preset tag, tag library added 2026-10-16 for this feature)
> **Reference module / docs / channels used:** project docs and code read for context: `CONTEXT.md`, `docs/architecture.md`, `lib/core/models/word_collection.dart`, `lib/core/models/session_source.dart`, `lib/features/notes/tag_editor.dart`, `lib/features/notes/tag_suggestions.dart`, `lib/features/notes/notes_screen.dart`, `lib/features/collections/name_dialog.dart`, `lib/features/collections/collections_screen.dart`.

## 1. Context

A learner now keeps many collections (one per book chapter, lesson, Quizlet set, film or trip) and has folders to sort them in, but nothing to say what a collection is *about* or *where it came from*, and no way to find one except opening folders. Today a collection has only a name. Its tags exist only as an untyped list buried on the Notes page, and a source's tags (a photo, a set, a film in the side panel) never reach the collection. "All my words from Friends about food" cannot be found.

Why now: the Collections screen just shipped (collections-screen, 2026-10-16), so the number of named collections and folders is growing. Sources already carry a title, description and tags (notes-editing, 2026-10-15). Tags are the missing link between "what I put in" and "how I find it again", and the owner asked for them on 2026-10-16.

Committed approach: every tag answers one of two guiding questions, **"Where does it come from?"** (an origin tag) or **"What is it about?"** (a topic tag). The learner fills both in one "Collection details" sheet, used both when making a new collection and from the main screen's edit button. The sheet also holds the name and a new description. Each tag field teaches by example: a helper line plus a row of tappable suggestions drawn from the learner's own tag library first and the preset tags second, with autocomplete while typing. Tags given to a source on the Notes page are copied up to its collection. The main screen shows the collection's tags as one line under the top bar, and a tap on a tag opens the Collections screen filtered by it. The Collections screen gains search and a filter by tags, by created time and by edited time, across all folders. Competitive research found that every product checked (Anki, Obsidian, Raindrop.io, Google Keep, LingQ, Bear) uses one flat tag list or a nesting convention. None of them asks two guiding questions with presets and tappable examples, and none rolls source tags up to a container. That gap is the reason for the two-kind design. The sharpest failure found is the one-time move of today's untyped tags into the two kinds, which must not lose a tag or let background work write back an older copy (AC-17, AC-17b, AC-18). Removing a tag from a source never removes it from the collection, and a collection already holding 10 tags of a kind does not take a copied tag (AC-16, AC-29). The edited time is the collection's existing last-change time, which a saved change to the words, name, description or tags moves, as Notes-page tag edits already do (AC-06), and the created time is the moment the collection was first made, which the app already knows for every collection (AC-25).

- Decision source: every product decision in this spec was made by a Fable 5.1 owner proxy, because the owner delegated them on 2026-10-16 ("made decision by your own").

## 2. Goals

- A learner can say where a collection's words came from and what they are about in the same step that names it, without typing tags from scratch.
- A learner can find any collection by a word in its name, description or tags, or by when it was made or last changed, without opening folders.
- Tags typed once are offered again everywhere, so the learner's tag vocabulary stays small and consistent.

## 3. Non-goals

- Tags on folders, on single word rows, or a filter of the main screen's word rows by tag. Tags are for finding collections, and a word-level filter is a separate feature.
- A "Manage tags" screen, renaming tags in bulk, or user-chosen tag colours. "Forget this tag" on a suggestion covers typo cleanup for now.
- Tags or description on the shared page, in exported files, or sent anywhere off the device. They stay on the device like source notes today, and the shared page is out of scope.
- Automatic tags on import (for example "Quizlet" for a set or "Film" for subtitles). Guessing tags for the learner is a later step once manual tagging is proven.

## 4. User stories

### US-01: Describe a new collection

**As a** learner
**I want** to give a new collection a name, a description, origin tags and topic tags in one sheet
**So that** I remember later where its words came from and what they are about

### US-02: Edit the current collection's details

**As a** learner
**I want** to open the same sheet from the edit button beside the main screen's title
**So that** I can add or change the description and tags of the collection I am working in

### US-03: Learn the two kinds of tag from examples

**As a** learner
**I want** each tag field to show examples and tappable suggestions from my own tags and the preset tags
**So that** I understand the difference between "where from" and "about what" and tag in one tap

### US-04: Reuse my tags with autocomplete

**As a** learner
**I want** every tag I add to be remembered on my device and suggested as I type
**So that** I do not create "food", "Food" and "foods" as three different tags

### US-05: See the collection's tags on the main screen

**As a** learner
**I want** the current collection's tags shown under the top bar, and a tap on one to show other collections with it
**So that** I see at a glance what I am working on and can jump to related collections

### US-06: Tag a source and have the collection follow

**As a** learner
**I want** a tag I add to a photo, set or film on the Notes page to be added to its whole collection too
**So that** I do not have to tag the same thing twice

### US-07: Search and filter collections

**As a** learner
**I want** to search collections by text and filter them by tags and by when they were created or last edited
**So that** I find the right collection without opening folders one by one

### US-08: Keep my existing tags

**As a** learner
**I want** the tags I already gave collections and sources before this change to still be there, sorted into the two kinds
**So that** I lose nothing when the app updates

### US-09: Partner sees only the words

**As a** partner
**I want** a shared link to show the collection's words without the learner's private description and tags
**So that** the learner can tag freely and still share the list

## 5. Acceptance criteria

### AC-01 (US-01) — happy path

**Given** the learner is on the Collections screen
**When** they choose New collection, enter the name "Friends S01", the description "Season 1 phrases", the origin tag "Series", and the topic tags "Everyday life" and "Idioms", then tap Create
**Then** the new collection appears in the open folder with that name, and opening its details sheet later shows the same description, one origin tag and two topic tags

### AC-02 (US-01) — happy path

**Given** the learner makes a new collection
**When** they enter only a name and tap Create
**Then** the collection is made with no description and no tags, because everything except the name is optional

### AC-03 (US-01) — error

**Given** the learner is filling in the Collection details sheet
**When** the name is empty or longer than 60 characters, or the description is longer than 500 characters
**Then** Create or Save stays unavailable and the sheet tells the learner, under the field, what the limit is

### AC-04 (US-03) — error

**Given** the learner types a tag
**When** the tag is empty after trimming spaces, longer than 30 characters, or contains a line break
**Then** the tag is not added and the field tells the learner that a tag is 1 to 30 characters on one line

### AC-05 (US-02) — happy path

**Given** the main screen shows a collection with no description and no tags
**When** the learner taps the edit button beside the title, adds the description "Chapter 3" and the topic tag "Food", then taps Save
**Then** the sheet closes, the title is unchanged, and a tag line with "Food" appears under the top bar

### AC-06 (US-02) — domain invariant

**Given** a collection that was last edited yesterday
**When** the learner saves a change to only its name, description or tags today (in the details sheet or on the Notes page)
**Then** the collection's edited time becomes today, as any other change to the collection does, its History place and the rule that decides whether the app reopens it on the next start treat it as touched, as tag edits on the Notes page already do; saving the sheet without any change moves nothing

### AC-07 (US-03) — happy path

**Given** the learner has never added a tag
**When** they open the Collection details sheet
**Then** under the origin field they see the hint "Where does it come from?", the helper line "e.g. Friends (series), a podcast, a trip to London" and up to 8 preset origin tags to tap; under the topic field the hint "What is it about?", the helper line "e.g. Food, Phrasal verbs, Job interview" and up to 8 preset topic tags; tapping a suggestion adds it to that field and removes it from the row

### AC-08 (US-03, US-04) — happy path

**Given** the learner has used the topic tag "Job interview" three times and "Cooking" once
**When** they open the topic field's suggestion row or type "co"
**Then** their own tags come before preset tags, the most used first, and typing "co" offers "Cooking" before any matching preset

### AC-09 (US-04) — domain invariant

**Given** the topic tag "Food" is already in the tag library
**When** the learner types "food" in a topic field and confirms it
**Then** the collection gets "Food" (the first spelling wins), and the tag library still holds one "Food"

### AC-10 (US-04) — domain invariant

**Given** a collection already has 10 topic tags
**When** the learner tries to add an 11th topic tag
**Then** the tag is not added and the field says that a collection holds at most 10 tags of each kind; origin tags can still be added up to their own 10

### AC-11 (US-04) — domain invariant

**Given** the text "Travel" is an origin tag of a collection
**When** the learner adds "Travel" as a topic tag as well
**Then** the collection shows "Travel" twice, once as an origin tag and once as a topic tag, because the two kinds are different tags

### AC-12 (US-04) — happy path

**Given** the learner mistyped a tag once as "Fodo" and it is now offered as a suggestion
**When** they long-press "Fodo" in the suggestion row or the autocomplete list and choose "Forget this tag"
**Then** "Fodo" is no longer suggested in any tag field, while every collection and source that has "Fodo" keeps it; preset tags never offer "Forget this tag"

### AC-13 (US-05) — happy path

**Given** the current collection has the origin tag "Book" and the topic tags "Food" and "Idioms"
**When** the learner looks at the main screen
**Then** one line under the top bar shows "Book" first, then "Food" and "Idioms", origin and topic tags each with their own icon and colour, and the line scrolls sideways when it does not fit; a collection with no tags shows no line, and when the first tag is added or the last one removed the line grows in or out smoothly so the word rows do not jump; the half-open photo panel may cover the line just as it may cover the top bar, and a tap on the panel goes to the panel

### AC-14 (US-05, US-07) — cross-context

**Given** the main screen shows the topic tag "Food"
**When** the learner taps it
**Then** the Collections screen opens showing only collections with the topic tag "Food", from every folder, with "Food" shown as an active filter that can be removed

### AC-15 (US-06) — cross-context

**Given** a collection with the photo source "Page 12" and no topic tag "Restaurants"
**When** the learner adds the topic tag "Restaurants" to that photo on the Notes page
**Then** the collection's topic tags also include "Restaurants", which appears in the main screen's tag line; adding it to a second source does not add it twice

### AC-16 (US-06) — domain invariant

**Given** the topic tag "Restaurants" was copied from a source to its collection
**When** the learner removes it from the source, or removes it from the collection
**Then** only that one place loses the tag: removals are never copied in either direction, and deleting a source never changes the collection's tags

### AC-17 (US-08) — happy path

**Given** before the update a collection had the untyped tags "Book", "food" and "Friends", and one of its sources had the tag "Podcast"
**When** the learner opens the app after the update
**Then** the collection has the origin tags "Book" and "Podcast" and the topic tags "food" and "Friends", the source has the origin tag "Podcast", and all four are in the tag library: a tag that matches an origin preset (ignoring case) became an origin tag, every other tag became a topic tag, every source tag was also copied to its collection, and no tag was lost

### AC-17b (US-08) — domain invariant

**Given** before the update a collection had the untyped tags "Travel" and "travel", a 40-character tag, and 14 other tags that all become topic tags
**When** the learner opens the app after the update
**Then** "Travel" and "travel" became one topic tag "Travel" (the first spelling kept wins), the 40-character tag is kept whole, and all 14 others are kept even though that is more than 10; the learner can remove any of them but cannot add another topic tag until fewer than 10 are left

### AC-18 (US-08) — cross-context

**Given** the learner's existing tags were sorted into the two kinds on the first start after the update, or the learner has just saved a description or tags
**When** any other save of the same collection follows (the main screen's autosave, a rename or move on the Collections screen, a source note edit, a finished story, a dialogue delivery, a learn result, a late lookup or import)
**Then** the collection's typed tags and description stay as the learner left them (its created time never changes, AC-25) and the old untyped tags never come back

### AC-19 (US-07) — happy path

**Given** collections in several folders, one named "Kitchen talk" with the description "From the cooking podcast"
**When** the learner opens search on the Collections screen and types "cook"
**Then** the screen lists every collection whose name, description, origin tags or topic tags contain "cook" (ignoring case) from all folders, each with its folder path under its name, and folders are hidden while the search is on

### AC-20 (US-07) — happy path

**Given** the learner opens the filter on the Collections screen
**When** they pick the origin tag "Series", the topic tag "Food", Created "Last 30 days" and sort "Recently edited"
**Then** only collections that have both tags and were created in the last 30 days are listed, most recently edited first, and each picked filter shows as a removable chip with a "Clear" action

### AC-20b (US-07) — happy path

**Given** the learner opens the filter on the Collections screen
**When** they pick Edited "Last 7 days"
**Then** only collections changed in the last 7 days are listed, a change to the words, name, description or tags counting as an edit (AC-06), and "Edited: last 7 days" shows as a removable chip

### AC-21 (US-07) — error

**Given** the learner picks a custom created range
**When** the start date is after the end date
**Then** the range is not applied and the filter tells the learner that the start must be on or before the end

### AC-22 (US-07) — domain invariant

**Given** a search or filter is on
**When** the learner long-presses a result or opens the recycle-bin delete mode
**Then** dragging, reordering and delete mode are not available until the search and filter are cleared, because a flat result list has no place in a folder to drop into

### AC-23 (US-07) — cross-context

**Given** a collection with the topic tag "Food" is in the recycle bin
**When** the learner filters by "Food" or searches for it
**Then** that collection is not listed, because a binned collection only shows in the recycle bin

### AC-24 (US-07) — happy path

**Given** a search or filter matches nothing
**When** the result list is empty
**Then** the screen says "No collections match" and offers a "Clear filters" button that brings back the open folder

### AC-25 (US-07, US-08) — happy path

**Given** a collection made before the update on 3 October, whose default name therefore shows "03.10.2026 14:30"
**When** the learner filters by Created "Custom range" 1–5 October
**Then** that collection is listed, because every collection, old or new, counts as created at the moment it was first made, the same moment its default name shows; a collection whose first moment cannot be read counts as created at its last edit, as History already does

### AC-27 (US-01, US-07) — happy path

**Given** the learner made the collection "Dark S1" in the details sheet with the origin tag "Netflix" and no words yet
**When** they search for "Dark" on the Collections screen, or open the origin field of another collection's details sheet
**Then** "Dark S1" is listed in the results, and "Netflix" is offered as one of the learner's own tags, because empty collections count for search, filters and the tag library while binned ones never do

### AC-28 (US-01, US-02) — domain invariant

**Given** a fresh, untouched collection with no words
**When** the learner gives it only a description or a tag and then leaves it for another collection
**Then** the collection is kept and stays on the Collections screen, because a description or a tag makes a collection a kept collection

### AC-29 (US-06) — domain invariant

**Given** a collection already has 10 topic tags
**When** the learner adds a new topic tag to one of its sources on the Notes page
**Then** the source gets the tag, the collection does not, and a short message says "The collection already has 10 topic tags — not added to it"

### AC-30 (US-04) — happy path

**Given** the learner once added the topic tag "Fodo" and later removed it from the only collection that had it
**When** they open a topic field's suggestions
**Then** "Fodo" is still in the tag library but comes after every tag in use (ranked by how many collections and sources use it, then by most recent), and before the preset tags; "Forget this tag" removes it from the library

### AC-31 (US-03, US-08) — domain invariant

**Given** the app's preset tags
**When** the learner opens a tag field or the migration sorts old tags
**Then** the origin presets are, in this order: Book, Film, Series, Cartoon, Song, Podcast, YouTube, Social media, Article, News, Textbook, Course, Lesson, Quizlet, Game, Conversation, Travel; the topic presets are: Everyday life, Food, Travel, Work, Business, IT, Health, Sport, Nature, Home, Shopping, Money, People, Emotions, Education, Phrasal verbs, Idioms, Slang, Grammar, Exam prep; an old untyped "Travel" becomes an origin tag, because it matches an origin preset

### AC-32 (US-08) — domain invariant

**Given** before the update collection X (made first) has the tag "food" and collection Y has "Food"
**When** the migration runs
**Then** X keeps "food", Y keeps "Food", and the tag library holds one topic tag spelled "food", because the library takes the first spelling it meets, visiting collections oldest first, each collection's own tags in their order and then each source's tags in source order; source tags are copied up even past 10, and the migration never un-forgets or ranks a tag as recently used

### AC-33 (US-06) — happy path

**Given** the learner removed the topic tag "Restaurants" from a collection while one of its sources still has it
**When** they add "Restaurants" to another source of that collection
**Then** the collection gets "Restaurants" again, because a new add is a new intent; saving a source note whose tags did not change copies nothing

### AC-34 (US-06) — happy path

**Given** the learner opens the Notes page
**When** they look at the collection's tags at the top and at a source's note
**Then** each shows two tag fields, origin and topic, with the same hints, helper lines and look as the details sheet; a field's suggestion row shows only while that field is focused; the Notes page does not show the description, which belongs to the details sheet

### AC-35 (US-04) — happy path

**Given** the tag library holds "Cooking" and "Home cooking", the preset "Series" exists, and the learner forgot "Fodo"
**When** they type "co" in a topic field, or type "series" in an origin field and confirm
**Then** "co" offers "Cooking" and "Home cooking" (matching the start of any word, ignoring case) but not "Tacos"; confirming "series" adds the preset spelling "Series"; ranking is: tags in use, the most collections first (a tag on a collection and its source counts once, binned collections count zero), ties broken by the last time the learner added it; then library tags in use nowhere; then presets; "Fodo" is never offered until the learner types and confirms it again; suggestion rows show only tags of the field's kind that are not already added

### AC-36 (US-01, US-02) — error

**Given** the learner changed something in the Collection details sheet
**When** they swipe it down, press Back or tap outside it
**Then** the sheet asks "Discard changes?" with Keep editing and Discard; with no change it closes without asking

### AC-37 (US-07) — happy path

**Given** collections in several folders
**When** the learner uses search and the filter together
**Then** a collection is listed only if it matches the search text and every picked tag (all picked tags, within a kind and across kinds) and both time choices; Created and Edited each offer Any time, Last 7 days, Last 30 days, This year and Custom range, counted in local calendar days ("Last 7 days" is today and the 6 days before; "This year" is 1 January until now; a custom range includes its whole first and last day); sorting offers My order (default: the folders' own order, folder by folder, each folder's collections where that folder sits), Name A–Z, Recently edited and Recently created

### AC-38 (US-07) — happy path

**Given** the learner opens the filter sheet
**When** they look at the tag sections
**Then** each kind lists the tags that at least one collection outside the recycle bin has, each with how many collections have it, the most used first then A–Z, showing the first 12 with a "Show all" toggle and a small field that narrows the list as they type; tags no collection has are not listed

### AC-39 (US-05, US-07) — happy path

**Given** the learner tapped the topic tag "Food" on the main screen and the Collections screen opened filtered by it
**When** they press Back, tap "Clear filters", or tap a result
**Then** Back returns straight to the main screen; "Clear filters" shows the folder the Collections screen opens at without a filter; a tapped result opens that collection as the current collection, as a normal tap does; the filter is by "Food" as a topic tag only, never an origin tag "Food"

### AC-26 (US-09) — authorization

**Given** a collection with a description and tags has been published
**When** a partner opens its shared link, or anyone receives one of its exported files
**Then** they see neither the description nor the tags, because both stay on the learner's device; only the learner, on their own device, can see or search them

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Search/filter response on the Collections screen | results update ≤ 100 ms after a keystroke or filter change with 500 collections and 2,000 tags | widget/perf test with a seeded store of 500 collections, on the CI runner |
| Autocomplete response | suggestions update ≤ 50 ms after a keystroke with 1,000 library tags | unit test timing the suggestion function |
| First start after the update (tag migration, including the case merge and the copy of source tags) | ≤ 1 s added to startup for 500 collections; runs once | test with a seeded store; launch log on the owner's phone |
| Migration accuracy | 100 % of pre-update tags present after the move (0 lost, 0 duplicated within a kind; merging spellings that differ only by case into the first one is not a loss, AC-17b) | migration test over a fixture of untyped tags on collections and sources |
| Main-screen tag line | adds no more than one line (≈ 40 dp) under the top bar and none when the collection has no tags | widget test on a phone-width screen |
| Write safety | 0 cases where a background save undoes a typed tag or description | tests that run each background save path after a details edit (AC-18) |

## 6.1 Security / privacy

- **Data classification:** internal — tags and descriptions are the learner's own notes about their collections, kept only on their phone.
- **Personal data touched:** new free-text fields that the learner may fill with anything: a collection description (up to 500 characters), origin and topic tags (new ones up to 30 characters each; tags from before the update are kept whole, AC-17b), and the tag library (kind, tag text, the last time the learner added it, a "forgotten" mark; use counts are worked out from the collections and sources that are not in the bin). No identifiers and nothing that leaves the device.
- **AuthZ/AuthN impact:** none new — the app has no accounts; the new data is never published, shared or exported, so the shared page's "anyone with the link" rule does not reach it (AC-26).
- **Abuse cases:**
  - Leak through sharing: a learner writes something private in a description or tag and then shares the collection → the description and tags are never sent with a publish or written to an export (AC-26).
  - Oversized input: pasted long text in a tag or description → blocked at 30 / 500 characters with a plain message (AC-03, AC-04).
  - Tag flooding slowing the screens: thousands of distinct tags → a new tag can be added only while a collection or source holds fewer than 10 of that kind (older over-limit lists are kept, AC-17b); suggestions show at most 8, and the library list is searched, not drawn in full.
  - Corrupt or older stored data: a record written before the update → migrated once, never re-read as untyped afterwards (AC-17, AC-18).
- **Security review:** N/A — no new data leaves the device, no new permission boundary and no accounts; the one sharing risk is closed by AC-26.

## 7. Metrics / KPIs

The app has no analytics; each KPI is measured by the owner on their own phone and in tests.

- **Collections with at least one tag** — baseline: 0 typed tags (untyped tags exist only on the Notes page), target: ≥ 60 % of the owner's collections made after the release carry at least one tag, within 30 days.
- **Time to find a known collection** — baseline: opening folders one by one (measured once by the owner before release), target: ≤ 10 s with search or one tag tap, within 14 days.
- **New collections given at least one tag in the details sheet when made** — baseline: 0, target: ≥ 50 % of the owner's new collections within 30 days, counted by the owner on the Collections screen (filter Created "Last 30 days", then compare with a tag filter); whether tags were tapped or typed is not measured, because the app has no analytics.
- **Distinct near-duplicate tags** — baseline: TBD, counted by the owner from the migrated library on the first start (pairs differing only by case or plural), target: 0 new case-only duplicates after release (guaranteed by AC-09), ≤ 2 plural duplicates in 30 days.

## 8. Open questions

- [ ] Should a tag on the main screen's tag line or on a Collections result also offer "show only this collection's words with this tag" one day? Default now: no — tags find collections only. — owner: owner (Maksym), due: after release, at the 30-day KPI check
- [ ] Should imports pre-fill an origin tag (Quizlet for a set, Film for subtitles)? Default now: no auto-tags (§3). — owner: owner (Maksym), due: after release, at the 30-day KPI check
