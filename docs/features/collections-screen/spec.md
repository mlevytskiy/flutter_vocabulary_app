---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-16"
feature_size: "L"
---

# Spec — collections-screen

> **Glossary:** [project CONTEXT](../../../CONTEXT.md) (collection, current collection, folder, recycle bin added or renamed 2026-10-16 for this feature)
> **Reference module / docs / channels used:** None beyond the interview + CONTEXT — `docs/architecture.md`, `docs/roadmap.md`, `docs/idea-brief.md`, `lib/core/models/session.dart`, `lib/features/word_input/word_input_screen.dart` (title, Next button, side menu), `lib/features/word_input/word_input_notifier.dart` (launch rule, switching), `lib/features/history/history_screen.dart` were read for context.

## 1. Context

A learner collects words into many collections — one per lesson, speaking club, Quizlet set or film — but today a collection has no name, no place and no way out. History lists them all by date as "N words", the main screen always says "English Vocabulary" whatever it holds, nothing can be grouped, and nothing can be deleted. Finding last month's "Phrasal verbs" list means opening History rows one by one. On top of that the app calls a collection a "session", a word the owner does not want the learner or the partner to see.

Why now: the number of collections is growing fast. Photos, Quizlet sets, film subtitles and dialogues each make new lists, and the Notes page just gave sources titles and tags, so a collection is the last thing in the app without a name. The launch rule also starts a fresh, unnamed collection after every pause of more than 5 minutes, so the top-level list keeps filling with date-only lists of a few words each.

Committed approach: a new Collections screen, opened from the side menu, that works like a Windows 95 folder window in the app's own style. It shows a grid of folder and collection icons, the current folder's path, and an Up button. A long press drags an icon into a folder, out to a level above, to a new place in the order, or onto the recycle bin. A tap opens a collection for work: it becomes the current collection. Every collection gets a name, shown in the main screen's title and changed from a new edit button beside it. Deleting a collection or a folder (with everything in it) puts it in a recycle bin for 30 days, from where it can be restored to its old place. The current collection can never be deleted. The research found no product that combines a real folder window (any depth, finger drag) with a 30-day bin that restores to the original place and protects the open item. Apple Notes, for example, restores to a default folder. The sharpest failure found was background work (the main screen's autosave, a finished story, a dialogue delivery) writing an older copy of a collection back and quietly undoing a new name, folder or order, or reviving a collection from the bin. So that is a hard requirement here (AC-27 and the "Name and place stability" row in §6).

- Decision (owner, 2026-10-16): "collection" replaces "session" in the app's code, in every text the learner sees, and in the shared page's text. Stored records keep their old stored names, so no word is moved or converted. The server's addresses and every link already given to a partner stay as they are. This is a deliberate exception to CLAUDE.md rule 3 ("move code, do not rewrite it"): the app's classes, fields, files and providers are renamed, their stored names stay pinned to the old ones, and on the server only the shared page's text changes, not its code (clarify, 2026-10-16).
- Decision (owner, 2026-10-16): the screen keeps the Windows 95 folder-window metaphor (folders, files, path, Up, drag and drop) but follows the app's own style. The retro look (grey frames, pixel icons) was offered and not chosen.
- Decision (owner, 2026-10-16): a tap on a collection in Collections switches to it with no question asked. This is on purpose and differs from History's Edit button, which still asks (edit-session-from-history US-02): switching loses nothing, the previous collection stays in its folder, and a drag needs a long press, so a short tap is never a drag.
- Decision (owner, 2026-10-16): the launch rule no longer starts new collections. After any pause the app reopens the current collection, and the RESTORE offer goes away. A new collection comes only from "New collection", or on the very first launch with nothing stored. This changes the behaviour edit-session-from-history built on.
- Decision (owner, 2026-10-16): an empty collection that the learner created with "New collection", renamed, or moved is kept. Only an untouched empty one disappears when the learner leaves it, as today.
- Decision (owner, 2026-10-16): a collection's default name is its creation date and time ("16.10.2026 14:30"). Existing collections get theirs from when they were really created, not from their last edit. A name is 1–60 characters, not only spaces, and has no line breaks. Two collections or folders may share a name.
- Decision (owner, 2026-10-16): History stays as it is, and its rows now show the name and the word count. The shared page shows the name, and so do shared files.
- Decision (owner, 2026-10-16, CLAUDE.md rules 3 and 5): the visible changes approved here are the Collections screen, the recycle bin, the edit button beside the main screen's title, the name as the main screen's title, the side menu always being there with its new Collections item, the ⋮ menu button on every icon, the drop zone for the recycle bin that shows during a drag, the name in History rows and on the shared page, the share sheet's warning that the name is public, the name in shared files' names and titles, and "collection" replacing "session" in the text. The new data approved is the collection's name, its folder and its place in the order, the folders, and the recycle bin entries, and (owner, 2026-10-16, during `sdd:design`) a flag that the collection is kept, which AC-19 needs.

## 2. Goals

- Every collection has a name, either its own or its creation date and time, and the learner sees that same name wherever the collection appears: the main screen, Collections, History, the shared page and shared files.
- The learner can arrange any number of collections into nested folders by finger drag, and the arrangement survives a restart and any background work.
- Nothing the learner deletes is lost for 30 days, and the collection the main screen is editing never disappears from under it.
- Words always land in the collection the learner chose. The app never switches or creates a collection on its own.

## 3. Non-goals

- Folders on the shared page, in exports or in a publish. Folders are the learner's own filing on the phone, and a partner has no use for them.
- Replacing History or showing folders in it. History stays the quick "latest first" list, and Collections is the filing view.
- Moving several items in one drag, or selecting several at once. One item per drag keeps a drag and a tap easy to tell apart. Batch moves can be added later.
- Sorting, searching or filtering on the Collections screen. The manual order is the order, as the owner asked.
- Merging two collections, or moving single word rows between collections. Both are separate features.
- A retro Windows 95 look (grey frames, pixel icons). The metaphor is kept, but the screen follows the app's own style.
- Renaming the collection from the shared page. The partner reads the name; only the learner sets it.
- Taking a published page down. Deleting a collection, even for good, leaves its shared page live until the page expires on its own.

## 4. User stories

### US-01: Name the collection I'm working in
**As a** learner
**I want** the main screen's title to show my current collection's name, with an edit button beside it
**So that** I always know which list I'm adding to and can name it in one tap

### US-02: See all my collections as folders and files
**As a** learner
**I want** a Collections screen in the side menu that shows my folders and collections like a folder window
**So that** I can find any list by where I put it, not by its date

### US-03: Open a collection to work in it
**As a** learner
**I want** a tap on a collection to make it my current collection and take me to the main screen
**So that** switching lists works like opening a file

### US-04: Stay in the collection I chose
**As a** learner
**I want** the app to reopen my current collection after any pause
**So that** my words never go into a list I didn't pick

### US-05: File collections into folders
**As a** learner
**I want** to create, name and nest folders
**So that** I can group lists by course, club or film

### US-06: Rearrange by dragging
**As a** learner
**I want** to drag collections and folders into folders, up a level, and into a new order
**So that** filing is as direct as on a desktop

### US-07: Rename anything from Collections
**As a** learner
**I want** to rename any collection or folder on the Collections screen
**So that** I can tidy old lists without opening each one

### US-08: Start a new collection
**As a** learner
**I want** a "New collection" button in the folder I'm looking at
**So that** a new lesson starts in the right place, even before it has words

### US-09: Delete without fear
**As a** learner
**I want** a deleted collection or folder to go to a recycle bin
**So that** a wrong delete costs me nothing

### US-10: Restore or erase from the recycle bin
**As a** learner
**I want** to restore items to where they were, see how long they will be kept, and erase them for good when I choose
**So that** the bin is a safety net I control

### US-11: Recognise collections in History
**As a** learner
**I want** History rows to show each collection's name and word count
**So that** the date list is readable too

### US-12: See the collection's name on the shared page
**As a** partner
**I want** the shared page to show the name of the collection I was sent
**So that** I know which lesson's words I'm looking at

### US-13: Share files named after the collection
**As a** learner
**I want** shared files to carry the collection's name
**So that** imported decks are easy to tell apart

### US-14: One word for one thing
**As a** learner
**I want** the app and the shared page to say "collection" everywhere they used to say "session"
**So that** the app speaks the language I use

## 5. Acceptance criteria

### AC-01 (US-01) — happy
**Given** a learner is on the main screen of their current collection
**When** they tap the white edit button beside the title, type "Phrasal verbs" and save
**Then** the title shows "Phrasal verbs", and the same name is shown for that collection in Collections and History, also after the app is restarted

### AC-02 (US-01, US-07) — error
**Given** a learner is renaming a collection or a folder
**When** they try to save a name that is empty, only spaces, longer than 60 characters, or holds a line break
**Then** the app does not save it, tells them in plain words that a name must be 1 to 60 characters on one line, and keeps the old name

### AC-03 (US-01) — happy
**Given** a learner has a collection they never renamed
**When** they look at it on the main screen, in Collections or in History
**Then** its name is its creation date and time, like "16.10.2026 14:30", and that name never changes when the collection is edited later

### AC-04 (US-01, US-02) — cross-context
**Given** a learner's phone holds collections from before this feature
**When** they open the updated app for the first time
**Then** every one of those collections appears at the top level of Collections, named by when it was really created (the moment recorded when it was made, or its earliest stored date when that cannot be read, shown in the phone's local time), with every word, photo, note, story and exercise result it had

### AC-05 (US-01) — happy
**Given** a learner's current collection has a name too long for the title bar
**When** they look at the main screen
**Then** the name is cut short with an ellipsis, and the edit button and the Next button stay fully visible and tappable

### AC-06 (US-02) — happy
**Given** a learner is on the main screen, with one collection or many
**When** they open the side menu
**Then** the menu is there and holds Main, Collections and History, and Collections opens the top level, with "Collections" as the path, Up unavailable, and every folder and collection there shown as an icon with its name in the learner's own order, followed by the recycle bin, which is always the last icon at the top level and cannot be moved, renamed or deleted

### AC-07 (US-02) — happy
**Given** a learner is looking at a folder on the Collections screen
**When** they look at a collection icon
**Then** it shows the collection's name and word count, and the current collection is visibly marked as current

### AC-08 (US-02, US-05) — happy
**Given** a learner is at the top level of Collections
**When** they tap the folder "English course", then its folder "Unit 3", then Up
**Then** the screen shows each folder's contents in turn, the path reads "Collections › English course › Unit 3" while inside, and Up brings them back to "English course"

### AC-09 (US-03) — happy
**Given** a learner's current collection is "Lesson 4" and "Lesson 3" is in a folder
**When** they tap "Lesson 3"
**Then** "Lesson 3" becomes the current collection and the main screen opens with its words and its name as the title, with no question asked, and "Lesson 4" stays in its folder with every word it had

### AC-10 (US-03) — happy
**Given** a learner is on the Collections screen
**When** they tap the collection that is already current
**Then** the main screen opens on it and nothing else changes

### AC-11 (US-03) — cross-context
**Given** a translation, photo reading, Quizlet or subtitle import is still running for the learner's current collection
**When** the learner opens another collection from Collections
**Then** the work finishes into the collection it started in, even if that collection is by then in the recycle bin, and never appears in the collection they just opened

### AC-12 (US-04) — domain invariant
**Given** a learner's current collection is "Travel" and they leave the app for any length of time
**When** they open the app again
**Then** the main screen shows "Travel" with its words, no new collection is made, and no restore offer appears. **Exactly one current collection** at all times: only a very first launch with nothing stored starts a first collection by itself. The current collection is the learner's own last choice: it changes only when they open a collection (AC-09) or make a new one (AC-18), and no background work changes it. If it is somehow missing, the newest collection outside the recycle bin opens, or a new one when there is none

### AC-13 (US-05) — happy
**Given** a learner is inside a folder on the Collections screen
**When** they choose "New folder" and give it a name
**Then** a folder with that name appears in the folder they are in, at the end of its order, and it is still there after a restart

### AC-14 (US-06) — happy
**Given** a learner is on the Collections screen
**When** they long-press a collection or folder and drop it onto a folder icon, onto Up, onto a part of the path, between two icons, onto another collection's icon, or onto the recycle bin drop zone that shows in every folder while dragging (at the top level that zone is the bin icon itself)
**Then** it moves into that folder, or to the level that was dropped on, or to that place in the order (dropped onto another collection's icon it takes that place and the rest shift along; collections never merge), or is deleted under the same rules and confirmation as Delete (AC-20 to AC-22), a folder takes everything inside it along, and the new arrangement is still there after a restart. A long press only becomes a drag once the finger moves; released without moving it opens the item's menu (AC-17). Holding a dragged item over a folder for about a second opens that folder and the drag goes on inside it

### AC-15 (US-06) — domain invariant
**Given** a learner is dragging the folder "English course"
**When** they drop it onto itself or onto a folder inside it, at any depth
**Then** the folder goes back where it was and the app says that **a folder cannot go inside itself**

### AC-16 (US-06) — happy
**Given** a learner long-presses an icon and starts to drag it
**When** they let go over an empty spot, outside the folder area, onto the path part or Up of the folder the item is already in, or onto Up at the top level
**Then** nothing moves, nothing opens, and the current collection does not change

### AC-17 (US-07) — happy
**Given** a learner is on the Collections screen
**When** they open the menu of any collection or folder, by a long press released without moving or by the ⋮ button on its icon, choose Rename and save a new name
**Then** the new name shows on its icon, and for a collection also in History and, if it is current, in the main screen's title

### AC-18 (US-08) — happy
**Given** a learner is inside the folder "Unit 3"
**When** they choose "New collection"
**Then** an empty collection named by its creation date and time appears at the end of "Unit 3", becomes the current collection, and the main screen opens on it

### AC-19 (US-08) — domain invariant
**Given** a learner has an empty collection
**When** they leave it by opening another collection or by making a new one
**Then** it is kept if they made it with "New collection", renamed it, moved it or reordered it, or if it ever had words. Only a collection with no words, photos or other sources, notes or tags, that the learner did none of these things to, disappears, and it is erased at once with no recycle bin entry. An empty collection never shows in History

### AC-20 (US-09) — happy
**Given** a learner is looking at a collection that is not current
**When** they choose Delete from its menu (long press or ⋮), or drop it onto the recycle bin, and confirm a question that names it and its word count
**Then** it leaves its folder and History and appears in the recycle bin, and its shared link, if it has one, keeps working

### AC-21 (US-09) — domain invariant
**Given** a learner is looking at their current collection on the Collections screen
**When** they try to delete it, from the menu or by dropping it onto the recycle bin
**Then** the app does not delete it and explains that **the current collection cannot be deleted** and they should open another collection first

### AC-22 (US-09) — happy
**Given** a learner has a folder holding collections and folders, one of them possibly the current collection
**When** they delete the folder, from the menu or by dropping it onto the recycle bin, and confirm a question that says how many collections and folders go to the bin and names the current collection as staying
**Then** the folder and everything in it go to the recycle bin as one item, except the current collection, which takes the folder's old place in the level above, stays current, and the app says so. Restoring that folder later brings back only what went to the bin; the current collection stays where it is

### AC-23 (US-10) — happy
**Given** a learner has items in the recycle bin
**When** they open the recycle bin icon, which opens only from the top level of Collections
**Then** they see each item with its name and "N days left" until it is erased, counted up: 30 on the day it was deleted and 1 on its last day, and a collection there cannot be opened or made current until it is restored

### AC-24 (US-10) — happy
**Given** an item is in the recycle bin
**When** the learner restores it
**Then** it returns to the folder it was deleted from, or to the top level if that folder is gone or is itself in the bin, a folder returns with everything that was inside it, and a collection comes back with every word, photo, note, story and exercise result it had

### AC-25 (US-10) — happy
**Given** an item is in the recycle bin
**When** the learner chooses Delete forever on it, or Empty recycle bin, and confirms a question that warns this cannot be undone
**Then** the item and its photos are erased from the phone, and, when a collection had a shared link, the question says that the shared page stays online until it expires and can no longer be updated from the app

### AC-26 (US-10) — domain invariant
**Given** an item has been in the recycle bin for 30 days
**When** the learner next opens the app or comes back to it
**Then** it is erased for good. **Nothing is erased before its 30 days are up**, even if the app was not opened in between, and "N days left" counts down to that same day. The phone's clock is trusted: if the learner moves it forward, items can be erased early, and that is accepted

### AC-27 (US-06, US-07, US-09) — cross-context
**Given** the main screen's automatic save, a translation, photo reading, Quizlet or subtitle import, a story, scene picture, dialogue delivery, photo upload or exercise result for a collection is still in progress
**When** the learner renames that collection, moves it, reorders it, deletes it, or erases it for good (Delete forever, Empty recycle bin or the 30-day erase), and then the work finishes
**Then** the new name, place and order are still there after the work finishes and after a restart, a deleted collection stays in the recycle bin and never comes back to a folder, History or the main screen on its own, and what the work produced is kept with the collection for when it is restored. Work that finishes after the collection was erased for good is dropped and never brings it back

### AC-28 (US-11) — happy
**Given** a learner has collections with words
**When** they open History
**Then** each row shows the collection's name and word count, with the date below, the current collection is still marked "current", and collections in the recycle bin are not listed

### AC-29 (US-12) — happy
**Given** a learner has named a collection "Speaking club 12"
**When** they share it as a link and the partner opens it
**Then** the shared page shows "Speaking club 12" as its title, and a later rename reaches the page only when the learner shares it as a link again, which updates the same page at the same link. Automatic deliveries of dialogues and pictures never change the name, and a page published before this feature keeps its old title until it is shared again

### AC-30 (US-12) — authorization
**Given** a partner holds the shared link of one collection
**When** they open the shared page
**Then** they see that collection's name and nothing about the learner's folders, other collections or recycle bin, and they cannot change the name. The page belongs to the learner's one collection, and the partner has no access to the learner's filing

### AC-31 (US-12) — happy
**Given** a learner is about to share a collection with its own name as a link
**When** the share sheet shows its public-page warnings
**Then** it also says that the collection's name will be visible to anyone with the link

### AC-32 (US-13) — happy
**Given** a learner shares a collection named "Unit 3: phrasal verbs?" as a file, in any of the five formats
**When** the file is made
**Then** its file name and the share's subject carry the collection's name, with each of \ / : * ? " < > | and any control character replaced by "-" (so "16.10.2026 14:30" becomes "16.10.2026 14-30") and "collection" used if nothing is left. Only the PDF also shows the name inside, as its heading, and the collection's own name is not changed

### AC-33 (US-14) — happy
**Given** a learner uses the app and a partner opens a shared page
**When** they read any message, label or empty-list text that used to say "session" — History's empty list, the photo panel's heading, the Notes page's tag field, the import results, the shared page
**Then** it now says "collection"

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Collections screen open time | ≤ 500 ms from tapping the menu item to a full icon grid, with 300 collections and 50 folders | release build on the owner's phone, screen-ready timing in a profile run |
| Move durability | a drop, rename, delete or restore survives a force-close made 1 s after it | device test: act, wait 1 s, kill the app, reopen, check |
| Name and place stability | 0 reverted names, places or orders, and 0 collections coming back from the bin, over 100 scripted runs of rename / move / delete / erase for good while background work for that collection finishes | automated test with each background writer |
| Update safety | 0 words, photos, notes, stories or exercise results lost when moving to the updated app | migration test over a copy of the owner's real data: counts before = counts after |
| Bin retention | erased no earlier than 30 × 24 h after deletion, and at the first app open after that | unit test with a controlled clock, including a clock moved backwards (a clock moved forward is trusted, AC-26) |
| Drag vs tap | 0 collection switches caused by a drag, over 50 scripted drags | widget test of long-press drags of every kind |

## 6.1 Security / privacy

- **Data classification:** internal — the learner's own word lists on their own phone; only a published collection's words, and now its name, are public to link holders.
- **Personal data touched:** the collection name and folder names are new free text typed by the learner (low sensitivity, but it can hold personal words like a person's name or an event). Folder names never leave the phone. The collection name leaves it only in a link the learner shares, and in shared files.
- **AuthZ/AuthN impact:** no new capability. The app still has no accounts; a link is the only credential to a shared page (`idea-brief.md` §5). What is new is one more field, the name, on the public page.
- **Abuse cases:**
  - Name leaks personal context: anyone with the link sees the name. The share sheet warns about it (AC-31), and a rename reaches the page only on the next share (AC-29).
  - Markup or script typed into a name: the shared page and the app show it as plain text, never as markup.
  - Folder structure leak: folders, other names and the bin never reach the page (AC-30).
  - A page no one can reach after "Delete forever": the learner is warned before erasing (AC-25), and the page still expires on its own 30-day life.
  - File-name tricks in a name (path separators, reserved characters): replaced in the shared file name (AC-32).
- **Security review:** Required — a learner-typed field newly appears on a public, editable page.

## 7. Metrics / KPIs

- **Collections with the learner's own name** — baseline: 0% (names do not exist yet); target: ≥ 50% of the collections created in the 30 days after release.
- **Named collections filed in a folder** — baseline: 0%; target: ≥ 80% of the learner-named collections within 30 days of release.
- **Words that went into the wrong collection** (owner reports "my words went into the wrong list" or "a list disappeared") — baseline: TBD, measured by counting top-level date-named collections with fewer than 5 words on the day of release; target: 0 such reports and 0 new auto-created collections in the 30 days after release.
- **Recycle bin restores** — baseline: 0 (no delete exists); target: tracked only. More than 0 restores in 60 days shows the bin is earning its place.

## 8. Open questions

- [x] Where in its folder's order does a restored item land: its old position or the end? Resolved (owner, 2026-10-16, `sdd:screens`): its old position when its neighbours are still there, otherwise the end — in the model, its old `order` when that is still within the level, otherwise the end ([screens SCR-08](./screens.md)).
- [x] What happens to a collection's story runs in Words settings → Story runs once it is erased for good? Resolved (owner, 2026-10-16, `sdd:design`): the runs stay listed, marked as from a deleted collection, and their pictures are kept — [sad §5](./sad.md#5-building-block-view).
