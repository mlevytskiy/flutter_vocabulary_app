---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)", "Security Lead"]
updated_at: "2026-10-16"
feature_size: "L"
target_surfaces: [mobile-app, backend-service, web-frontend]  # decided in §4 (ADR-0001) — subset of: backend-service | web-frontend | mobile-app | desktop-app | cli | worker | library-sdk. Read (never re-derived) by api/sequences/tasks/plan-tests/review → _shared/surfaces.md
---

# Software Architecture Document — collections-screen

<!-- 12 Arc42 sections. Empty section → <!-- N/A: <one-line reason> -->. -->
<!-- C4 Context (L1) lives inline in §3. C4 Container (L2) lives inline in §5. -->
<!-- Numbers in §10 come VERBATIM from spec.md §6 NFR — no inventing, no rounding. -->

## 1. Introduction and goals

**Intent.** Give every collection a name and a place. The main screen's title shows the current collection's name, with an edit button beside it. A new Collections screen, opened from the side menu, works like a folder window: nested folders, finger drag, a path and Up. A 30-day recycle bin restores deleted items to where they were. The app always reopens the collection the learner chose and never makes one by itself. The word "session" becomes "collection" in the app's code and in every text the learner and the partner read ([spec](./spec.md) §1–§2).

**Top-3 quality goals (1-liners; full scenarios in §10):**

1. Name and place stability: no background writer can undo a rename, a move or a delete, or bring a collection back from the bin (AC-27).
2. Update safety: moving to the updated app, with the rename and the new filing data, loses no word, photo, note, story or exercise result (AC-04).
3. A responsive folder window: Collections opens fast with hundreds of collections, and a drag never switches the current collection.

**Stakeholders.**

| Role | Interest | Sign-off owner? |
|---|---|---|
| learner | names, files, opens and deletes collections on the phone | No |
| partner | reads the name on a shared page, and nothing else of the learner's filing | No |
| Security Lead | the learner-typed name newly shown on a public, editable page (spec §6.1) | No |
| Tech Lead (Maksym) | SAD approval | Yes |

## 2. Constraints

**Technical.**
- Flutter, Dart SDK `>=3.0.0 <4.0.0`; `flutter_riverpod` / `riverpod_annotation` 2.6.x with `riverpod_generator` ^2.6.1; `go_router` ^17.2.3 with `go_router_builder` ^3.0.0 typed routes (`lib/router/routes.dart`).
- Persistence: `isar_community` pinned to `3.3.0-dev.1` (database `vocab`: collections `Session` and `StoryRun`). Isar keys a stored collection and its properties by name, so a class or field renamed in Dart must keep its stored name with `@Name` (precedent: `SessionSource` is stored as `SourcePhoto`). Isar adds new properties with null/default values to old records; there is no migration framework, so one-time fixes run when the store opens (precedent: `_fillRowIdsEverywhere`).
- `shared_preferences` holds the current-collection pointer (`current_session_id`), plus the History pick and seen records that this feature retires.
- `SessionStore.put` is a whole-record upsert from the caller's copy. Only `results` is protected today (`session_store.dart:113-151`). Writers that read, change and put a whole copy: the main screen's debounced autosave (`word_input_notifier.dart`), `story_run_tracker.dart:465,489`, `word_groups_notifier.dart:213` and `dialogue_push.dart:327-331`.
- Worker: TypeScript on Cloudflare Workers with D1 (`vocab-photo-api/`, migrations `0001`–`0006`). The shared page is server-rendered HTML from `src/session/page.ts`, today titled "Vocabulary".
- No drag-and-drop or reorderable-grid package is in `pubspec.yaml`, and none may be added (CLAUDE.md rule 5).

**Organisational.**
- One owner designs, builds, reviews and ships. No deadline. Effort budget: L (several PRs over more than a week, per `.size`).

**Conventions.**
- [`CLAUDE.md`](../../../CLAUDE.md) rules 1–7 and [`docs/architecture.md`](../../architecture.md): typed routes only; services from `lib/core/providers.dart`; screen data in a `@riverpod` notifier, controllers/focus/drag flags in widget `State`; no new packages; new data only as the spec approves (§1 last decision: name, folder, place in the order, folders, recycle bin entries), plus the `keep` flag that AC-19 needs, approved by the owner on 2026-10-16 during design.
- Rule 3 exception approved by the spec (§1, decision 1): the app's classes, fields, files and providers are renamed from session to collection, not only moved; stored names stay pinned.
- Tests per [`docs/testing.md`](../../testing.md): `tool/test.sh smoke` while developing, `tool/test.sh changed` before finishing; Worker tests in `vocab-photo-api/test/`.

**Regulatory / external.**
- No accounts and no personal-data processing beyond the learner's own phone. The collection name leaves the phone only in a shared link or a shared file the learner makes (spec §6.1). Security review required: a learner-typed field newly appears on a public, editable page.

## 3. Context and scope

The learner keeps many collections on the phone, one per lesson, club, set or film. This feature names them, files them into folders, and adds a recycle bin, all on the phone. The only thing that crosses the phone's boundary is the collection's name: it goes to the Worker with a shared-link publish and appears as the shared page's title, and it names shared files. Folders, other collections and the bin never leave the phone.

<!-- brownfield: Isar `Session` rows + a shared_preferences pointer (SessionStore); WordInputNotifier owns the current session and runs a 5-minute launch rule with a RESTORE offer; History watches non-empty sessions; the drawer shows only with other sessions; whole-record put() by four writers; the Worker's D1 `sessions` table has no title. -->

**External systems (in / out):**

| Actor or system | Type | Interaction |
|---|---|---|
| learner | Person | names, files, opens, deletes and restores collections on the phone |
| partner | Person | opens a shared link and reads the collection's name as the page title |
| vocab-photo-api (Worker) | System (internal) | receives the name with a shared-link publish and stores it beside the published collection |
| shared page | System (internal) | served by the Worker; shows the name as its title, nothing about folders or the bin |
| phone's share targets | System (external) | receive shared files named after the collection |

**C4 Context (L1):**

```mermaid
C4Context
    title collections-screen — System Context

    Person(learner, "Learner", "Collects words into named collections and files them in folders on the phone")
    Person(partner, "Partner", "Opens one collection's shared link")
    System(app, "Vocabulary app", "Flutter app on the learner's phone; stores collections, folders and the recycle bin locally")
    System(worker, "vocab-photo-api and shared page", "Cloudflare Worker storing published collections and serving their shared page")
    System_Ext(targets, "Phone share targets", "Mail, messengers, Anki and other apps that receive shared files")

    Rel(learner, app, "Names, files, opens, deletes and restores collections")
    Rel(app, worker, "Publishes a collection with its name on Share link", "HTTPS")
    Rel(partner, worker, "Reads the shared page titled with the name", "HTTPS")
    Rel(app, targets, "Hands over files named after the collection", "Android share sheet")
```

## 4. Solution strategy

**Top strategic choices (the seeds for ADRs):**

1. **Three surfaces: the app, the Worker and the shared page** ([ADR-0001](adr/0001-change-the-app-the-worker-and-the-shared-page-as-three-surfaces.md)). `target_surfaces: [mobile-app, backend-service, web-frontend]`. Almost all the work is in the app. The Worker gains a nullable title stored with a published collection; the shared page shows it as its heading and swaps "session" for "collection" in its text. UI architecture is unchanged on both UI surfaces: the app stays Flutter (cross-platform, typed go_router routes, Riverpod notifiers); the page stays server-rendered HTML with one plain-JavaScript file (good-looking-web ADR-0002). Serves quality goal 2 and spec AC-29–AC-31, AC-33.
2. **Rename first, as a mechanical step with stored names pinned** ([ADR-0002](adr/0002-rename-session-to-wordcollection-with-stored-names-pinned.md)). `Session` becomes `WordCollection`, `sessionId` becomes `collectionId`, `SessionStore` becomes `CollectionStore`, and so on through files and providers. `@Name('Session')`, `@Name('sessionId')` and the unchanged `shared_preferences` keys keep every stored record readable as it is. Worker routes, JSON field names and shared links do not change. The rename lands before any behaviour change, with every existing test green, so that a data problem can only come from one place. Serves quality goal 2.
3. **Filing lives on the records, and only dedicated store transactions write it** ([ADR-0003](adr/0003-keep-filing-on-the-collection-row-written-only-by-store-transactions.md), [ADR-0004](adr/0004-store-folders-as-their-own-isar-collection-linked-by-parent-id.md), [ADR-0005](adr/0005-mark-a-deleted-item-in-place-and-let-a-binned-folders-contents-follow-it.md)). A collection gets `name`, `folderId`, `order`, `binnedAt`, `binnedFromFolderId` and `keep`. `put()` never writes these fields, except that it may raise `keep` to true when its copy has words (never back to false), and never creates a missing record. A new Isar collection `CollectionFolder` holds folders with a parent link. Deleting marks the item in place, and a binned folder's contents follow it. Rename, move, reorder, bin, restore and erase are each one Isar write transaction in `CollectionStore`. Serves quality goals 1 and 3.
4. **Late work lands in its own collection through an atomic update** ([ADR-0006](adr/0006-deliver-late-results-into-their-own-collection-through-an-atomic-store-update.md)). `CollectionStore.update(collectionId, change)` reads, changes and writes one record inside one transaction, and does nothing when the record is gone. Every background writer uses it, and so does a translation, photo reading, Quizlet or subtitle result that returns after the learner opened another collection. This replaces "drop a result for another session" (edit-session-from-history ADR-0003, import-from-quizlet). Serves quality goal 1 and AC-11.
5. **The current collection is the learner's choice, nothing else** ([ADR-0007](adr/0007-reopen-the-current-collection-after-any-pause.md)). The launch rule loses its 5-minute window, the RESTORE offer, and the seen and History-pick records. It reopens the pointer's collection; if that is missing or in the bin, it reopens the newest collection outside the bin; with nothing stored, it starts a first one. The store refuses to bin the current collection. Serves AC-12, AC-21.
6. **The name reaches the shared page only through Share link** ([ADR-0008](adr/0008-send-the-collection-name-as-the-shared-pages-title-in-a-nullable-column.md)). The publish payload carries `title`. D1 migration `0007` adds a nullable `title` column. Only a create or republish writes it; dialogue and picture deliveries never touch it. The page shows `title`, escaped, or "Vocabulary" when it is null. Serves AC-29, AC-30.

Each tactical decision in later sections should trace to one of these seeds. Tactical decisions that *contradict* a strategic choice are red flags — surface them in §11.

## 5. Building block view

The app keeps the repo's layering: feature folders under `lib/features/`, shared models and services under `lib/core/`, typed routes in `lib/router/routes.dart`, services reached through `lib/core/providers.dart`. The new screens are a feature folder of their own. They talk to the rest only through providers and routes, never by importing another feature's screen (architecture.md rule 3): `CollectionStore` for filing, and `wordInputNotifierProvider` to open a collection or start a new one, because the notifier owns the current collection and must flush it, apply AC-19 to it and switch the pointer (§6 flow 2).

**Internal decomposition:**

```
lib/
  core/
    models/
      word_collection.dart (+.g)   WordCollection — renamed Session, @Name('Session'); new fields:
                                   name, folderId, order, binnedAt, binnedFromFolderId, keep (ADR-0003, ADR-0005)
      collection_folder.dart (+.g) CollectionFolder — new Isar collection: folderId, name, parentId,
                                   order, binnedAt, binnedFromFolderId (ADR-0004)
      collection_name.dart         pure: the 1–60 characters, one-line rule; the default name
                                   "dd.MM.yyyy HH:mm"; the creation moment from a collectionId
    services/
      collection_store.dart        renamed SessionStore. put() keeps filing fields and never inserts;
                                   create(); update(id, change) (ADR-0006); rename, move, reorder,
                                   bin, restore, erase, sweepBin; watchLevel(folderId), watchBin(),
                                   watchHistory(); the one-time filing backfill on open
      filing.dart                  pure rules: ancestors/descendants of a folder, "is it in the bin
                                   (itself or an ancestor)", a folder into itself (AC-15), the level
                                   renumbering, the restore target (AC-24), days left (AC-23),
                                   the 30-day expiry (AC-26), the empty-and-untouched rule (AC-19)
  features/
    collections/
      collections_screen.dart      the folder window: path, Up, New folder, New collection, grid
      collections_notifier.dart(+.g) the open folder id, the level's items, the path; filing
                                   actions call CollectionStore, open and New collection call
                                   wordInputNotifierProvider
      collection_icon.dart         one folder or collection icon with its ⋮ button; LongPressDraggable
                                   and DragTarget built into Flutter
      collection_drag.dart         drop-target rules for the grid, Up, the path and the bin zone,
                                   the 1 s hover-to-open timer (widget State)
      recycle_bin_screen.dart      bin list with "N days left", item menu, Empty recycle bin
      name_dialog.dart             the name dialog shared by the main screen and Collections
    word_input/                    title shows the name + edit button; the side menu always on,
                                   with Main / Collections / History; launch rule (ADR-0007)
    history/                       rows show name + word count; binned collections left out
    words_table/                   share_formats.dart: safeFileName(name); PDF heading; share subject;
                                   the share sheet's warning that the name is public (AC-31)
  core/services/collection_publish_service.dart  renamed session_publish_service; the publish
                                   body gains `title` (ADR-0008)
  router/routes.dart               + CollectionsRoute, RecycleBinRoute
vocab-photo-api/
  migrations/0007_session_title.sql  nullable title on sessions (+ down)
  src/session/                       handlers.ts reads title on create/republish; page.ts heading
                                     and "collection" wording
```

- **Extend vs new module.** `CollectionStore` stays the one owner of collection persistence. Folders go in the same store (same Isar instance, same transactions), because a move, a bin or an erase must change a folder and its collections in one transaction.
- **Story runs after an erase** (spec §8 open question, resolved by the owner 2026-10-16): the runs stay in Words settings → Story runs, marked "from a deleted collection", and their pictures are kept. The mark is worked out when the list is shown (no collection with that id exists any more); `StoryRun` and its store do not change.
- **The 30-day sweep** (`sweepBin`) runs when the store opens and when the app comes back to the foreground. It erases the records and the `source_photos/` files of each expired collection and of everything inside an expired folder.

**C4 Container (L2):**

```mermaid
C4Container
    title collections-screen — Containers

    Person(learner, "Learner")
    Person(partner, "Partner")

    Container_Boundary(phone, "Vocabulary app on the phone") {
        Container(mobile, "Flutter app", "Flutter, Riverpod, go_router", "Main screen, Collections screen, recycle bin, History, share sheet")
        ContainerDb(isar, "Isar vocab", "isar_community 3.3.0-dev.1", "Collections with their filing fields, folders, story runs")
        ContainerDb(prefs, "shared_preferences", "key-value", "The current collection pointer")
        ContainerDb(files, "Photo files", "app documents dir", "source_photos and mnemonic_pictures")
    }

    Container_Boundary(cloud, "Cloudflare") {
        Container(worker, "vocab-photo-api", "TypeScript Worker", "Stores published collections with their title")
        ContainerDb(d1, "D1", "SQLite", "sessions table with the new nullable title")
        Container(page, "Shared page", "Server-rendered HTML and plain JavaScript", "Shows one published collection titled with its name")
    }

    Rel(learner, mobile, "Names, files, opens, deletes, restores")
    Rel(mobile, isar, "Reads and writes collections and folders", "Isar transactions")
    Rel(mobile, prefs, "Reads and sets the current collection")
    Rel(mobile, files, "Keeps and erases photos")
    Rel(mobile, worker, "Publishes a collection with its name", "HTTPS JSON")
    Rel(worker, d1, "Stores the title", "D1")
    Rel(worker, page, "Renders")
    Rel(partner, page, "Reads", "HTTPS")
```

## 6. Runtime view

**Critical flow 1: a rename survives a background writer finishing (AC-27)**

```mermaid
sequenceDiagram
    actor Learner
    participant Screen as Collections screen
    participant Notifier as CollectionsNotifier
    participant Store as CollectionStore
    participant Isar as Isar vocab
    participant Writer as Background writer
    Writer->>Store: reads the collection, starts its work
    Learner->>Screen: renames it to "Phrasal verbs"
    Screen->>Notifier: rename
    Notifier->>Store: rename in one transaction
    Store->>Isar: writes name and keep only
    Isar-->>Store: committed
    Writer->>Store: update with its result
    Store->>Isar: reads the stored record, applies only the writer's change
    alt record still there
        Isar-->>Store: committed, name untouched
    else erased for good meanwhile
        Store-->>Writer: nothing written, result dropped
    end
    Store-->>Screen: level stream shows "Phrasal verbs"
```

**Critical flow 2: opening another collection while a lookup runs (AC-09, AC-11, AC-19)**

```mermaid
sequenceDiagram
    actor Learner
    participant Screen as Collections screen
    participant Main as WordInputNotifier
    participant Store as CollectionStore
    participant Lookup as Translation lookup
    Main->>Lookup: translate a row of "Lesson 4"
    Learner->>Screen: taps "Lesson 3"
    Screen->>Main: open "Lesson 3"
    Main->>Store: flush "Lesson 4", erase it only if empty and untouched
    Main->>Store: set the current pointer to "Lesson 3"
    Main-->>Screen: main screen shows "Lesson 3"
    Lookup-->>Main: result for "Lesson 4"
    Main->>Store: update "Lesson 4" with the result
    Note over Main,Store: "Lesson 3" never sees the result
```

**Critical flow 3: the 30-day sweep at launch (AC-26)** — the store opens, `sweepBin` finds items whose `binnedAt` is at least 30 × 24 h ago, and in one transaction erases them (and every record inside an expired folder); their photo files are deleted after the commit. The `sequences` stage draws this flow and covers every remaining AC.

### Flows by user story (sequences stage)

Participants are generic: `user` is the learner or the partner, `ui` a screen or dialog, `service` the logic that owns the flow, `data-store` the phone's database, pointer or files (the Worker's database on the server side). Persist notes mark every write for `data-model`.

### F1 — Rename a collection or folder (US-01, US-07)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the main screen of the current collection, or an item menu on the Collections screen
    U->>UI: taps the edit button beside the title, or Rename in the item menu
    UI-->>U: name dialog with the current name filled in
    U->>UI: types a new name and saves
    UI->>S: validate the name
    alt empty, only spaces, over 60 characters or a line break
        S-->>UI: refused by the name rule
        UI-->>U: says a name must be 1 to 60 characters on one line, keeps the old name, dialog stays open
    else valid name
        S->>D: rename in one transaction, writes only the name and keep
        Note over S,D: persists collection.name and collection.keep, or folder.name
        D-->>S: committed
        S-->>UI: renamed
        UI-->>U: the icon shows the new name, and for the current collection the main screen title too
        Note over UI,D: History and the title watch the stored name, so they follow at once and after a restart
    end
    opt Cancel
        U->>UI: cancels
        UI-->>U: nothing changes
    end
    Note over U,D: Postcondition: an edit of the words never changes the name, a default date name stays as it was made
```

### F2 — Browse the Collections screen (US-02)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the side menu is always available and holds Main, Collections, History
    U->>UI: opens the side menu and taps Collections
    UI->>S: open the top level
    S->>D: read the folders and collections of the top level that are not in the bin, by order
    D-->>S: items with name, word count, order
    S->>D: read the current collection pointer
    D-->>S: current collection id
    S-->>UI: the level, path "Collections", Up unavailable
    UI-->>U: icons in the learner's order, the current collection marked, the recycle bin last
    U->>UI: taps the folder "English course", then "Unit 3"
    UI->>S: open each folder
    S->>D: read that folder's items, and its ancestors for the path
    D-->>S: items and ancestors
    S-->>UI: the level and the path
    UI-->>U: the path reads Collections, English course, Unit 3
    alt Up, or a tap on a part of the path
        U->>UI: taps Up
        UI->>S: open the parent folder
        S-->>UI: the parent level
        UI-->>U: back in "English course"
    else the recycle bin icon at the top level
        U->>UI: taps the bin icon
        UI-->>U: the recycle bin screen, see F9
    end
    Note over U,D: Postcondition: browsing writes nothing and never changes the current collection
```

### F3 — Open a collection with a tap (US-03)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the Collections screen shows a folder holding "Lesson 3", the current collection is "Lesson 4"
    U->>UI: taps "Lesson 3"
    UI->>S: open "Lesson 3"
    alt "Lesson 3" is already current
        S-->>UI: nothing to switch
        UI-->>U: the main screen on "Lesson 3", nothing else changes
    else another collection
        S->>D: flush the pending autosave of "Lesson 4"
        Note over S,D: persists the words of "Lesson 4"
        alt "Lesson 4" is empty, has no sources, notes or tags, and is not kept
            S->>D: erase "Lesson 4" at once, no bin entry
            Note over S,D: deletes the collection record
        else kept or has content
            Note over S,D: "Lesson 4" stays in its folder with everything it had
        end
        S->>D: set the current pointer to "Lesson 3"
        Note over S,D: persists the current collection pointer
        S->>D: read "Lesson 3"
        D-->>S: its words and name
        S-->>UI: "Lesson 3" is current
        UI-->>U: the main screen with its words and its name as the title, no question asked
    end
    opt a translation, photo reading or import for "Lesson 4" returns later
        S->>D: update "Lesson 4" with the result in one transaction, even if it is in the bin
        Note over S,D: persists the result on "Lesson 4" only
        Note over S,UI: the main screen on "Lesson 3" never shows it
    end
    Note over U,D: Postcondition: exactly one current collection, the one the learner tapped
```

### F4 — App launch or return (US-04)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,S: Trigger: the app is opened, or comes back to the foreground after any pause
    U->>UI: opens the app
    UI->>S: start
    opt first open after the update
        S->>D: read collections without a name
        D-->>S: old collections
        S->>D: name each from the moment in its id, else its earliest stored date, local time, top level, oldest first
        Note over S,D: persists name, folder, order once per old collection, words untouched
    end
    S->>D: read bin items whose 30 times 24 hours are up
    D-->>S: expired items
    opt any expired
        S->>D: erase them and everything inside expired folders in one transaction
        S->>D: delete their photo files after the commit
        Note over S,D: deletes collection and folder records and photo files
    end
    S->>D: read the current pointer and its collection
    D-->>S: pointer and record
    alt nothing stored at all
        S->>D: create a first collection named by date and time at the top level and point at it
        Note over S,D: persists the new collection and the pointer
    else the pointer's collection exists and is not in the bin
        Note over S,D: it stays current, however long the pause
    else pointer missing, or its collection is in the bin
        S->>D: read the newest collection outside the bin
        alt one exists
            S->>D: point at it
        else none
            S->>D: create a new collection and point at it
        end
        Note over S,D: persists the pointer
    end
    S-->>UI: the current collection
    UI-->>U: the main screen with its words and name, no new collection, no restore offer
    Note over U,D: Postcondition: the current collection changed only if it was missing, nothing older than 30 days stays in the bin
```

### F5 — New folder (US-05)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the Collections screen shows some folder or the top level
    U->>UI: chooses New folder
    UI-->>U: name dialog
    U->>UI: types a name and saves
    UI->>S: create the folder here
    alt the name breaks the 1 to 60 characters, one line rule
        S-->>UI: refused by the name rule
        UI-->>U: same explanation as a rename, dialog stays open
    else valid
        S->>D: create the folder at the end of this level in one transaction
        Note over S,D: persists folder with name, parent and order
        D-->>S: committed
        S-->>UI: the level with the new folder last
        UI-->>U: the folder is the last icon, and opens on a tap like any other
    end
    Note over U,D: Postcondition: the folder is still there after a restart
```

### F6 — Rearrange by dragging (US-06)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the Collections screen shows a level
    U->>UI: long-presses an icon
    alt released without moving
        UI-->>U: the item menu, see F1 and F8
    else the finger moves
        UI-->>U: dragging, the recycle bin drop zone shows
        opt held over a folder for about a second
            UI->>S: open that folder
            S-->>UI: its level
            UI-->>U: the drag goes on inside it
        end
        U->>UI: drops the item
        alt on a folder icon
            UI->>S: move into that folder
            S->>D: read the target's ancestors
            D-->>S: ancestors
            alt the target is the dragged folder itself or inside it
                S-->>UI: refused, a folder cannot go inside itself
                UI-->>U: it springs back and the app says so
            else allowed
                S->>D: change its folder and renumber both levels in one transaction
                Note over S,D: persists folderId or parentId, order, keep
                UI-->>U: it shows inside the folder, a folder with all its contents
            end
        else on Up or a part of the path
            UI->>S: move to that level
            S->>D: change its folder and renumber in one transaction
            Note over S,D: persists folderId or parentId, order, keep
            UI-->>U: it leaves this level
        else between icons or on another collection's icon
            UI->>S: reorder to that place
            S->>D: renumber the level in one transaction
            Note over S,D: persists order and keep, collections never merge
            UI-->>U: it takes that place and the rest shift along
        else on the recycle bin drop zone
            UI-->>U: delete, see F8
        else an empty spot, outside, its own folder's path or Up, or Up at the top
            UI-->>U: nothing moves, nothing opens
        end
    end
    Note over U,D: Postcondition: a drag never changes the current collection, every move is still there after a restart
```

### F7 — New collection (US-08)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the Collections screen is inside "Unit 3"
    U->>UI: chooses New collection
    UI->>S: new collection in "Unit 3"
    S->>D: flush the collection being left
    alt the left one is empty, has no sources, notes or tags, and is not kept
        S->>D: erase it at once, no bin entry
        Note over S,D: deletes the collection record
    else kept or has content
        Note over S,D: it stays where it is
    end
    S->>D: create a kept, empty collection named by its date and time at the end of "Unit 3"
    Note over S,D: persists the collection with name, folderId, order, keep
    S->>D: point at it
    Note over S,D: persists the current collection pointer
    D-->>S: committed
    S-->>UI: it is current
    UI-->>U: the main screen on the new, empty collection
    Note over U,D: Postcondition: it is kept even if left empty, and it shows in History only once it has words
```

### F8 — Delete to the recycle bin (US-09)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: an item menu Delete, or a drop on the recycle bin zone
    U->>UI: deletes an item
    UI->>S: what would go to the bin
    S->>D: read the item, its contents and the current pointer
    D-->>S: item, counts, current id
    alt the item is the current collection
        S-->>UI: refused, the current collection cannot be deleted
        UI-->>U: open another collection first
    else another collection
        UI-->>U: confirm, naming it and its word count
        U->>UI: confirms
        UI->>S: bin it
        S->>D: mark it binned with the time and its folder, in one transaction that re-checks the current pointer
        Note over S,D: persists binnedAt and binnedFromFolderId
        UI-->>U: it leaves its folder and History and is in the bin, its shared link keeps working
    else a folder
        UI-->>U: confirm, counting collections and folders, naming the current one as staying
        U->>UI: confirms
        UI->>S: bin the folder
        alt the current collection is inside
            S->>D: move the current collection to the folder's old place, then mark the folder binned, in one transaction
            Note over S,D: persists the current collection's folderId and order, the folder's binnedAt and binnedFromFolderId
            UI-->>U: the folder is in the bin as one item, and the app says the current collection stayed
        else not inside
            S->>D: mark the folder binned in one transaction
            Note over S,D: persists binnedAt and binnedFromFolderId
            UI-->>U: the folder and everything in it is one bin item
        end
    end
    opt Cancel at the confirmation
        UI-->>U: nothing changes
    end
    Note over U,D: Postcondition: nothing is erased, the current collection is never in the bin
```

### F9 — Restore or erase from the recycle bin (US-10)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    Note over U,UI: Precondition: the recycle bin icon at the top level of Collections
    U->>UI: opens the recycle bin
    UI->>S: list the bin
    S->>D: read binned items
    D-->>S: items with binnedAt
    S-->>UI: items with N days left, 30 on the day of deletion down to 1
    UI-->>U: the list, a collection here cannot be opened
    U->>UI: opens an item's menu
    alt Restore
        UI->>S: restore it
        S->>D: read its old folder
        alt the old folder exists and is not in the bin
            S->>D: clear the mark, back in the old folder, in one transaction
        else gone or in the bin
            S->>D: clear the mark, back at the top level, in one transaction
        end
        Note over S,D: persists binnedAt cleared, folderId, order
        UI-->>U: it is back with everything it had, a folder with all that went with it
    else Delete forever, or Empty recycle bin
        UI-->>U: confirm, cannot be undone, a shared page stays online and can no longer be updated
        U->>UI: confirms
        UI->>S: erase
        S->>D: delete the item, or every bin item, and everything inside, in one transaction
        S->>D: delete their photo files after the commit
        Note over S,D: deletes collection and folder records and photo files, story runs stay
        UI-->>U: gone from the bin
    end
    Note over U,D: Postcondition: a restored item is outside the bin, an erased one never comes back
```

### F10 — Cross-cutting: background work against a filing change (AC-27)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant W as service (background writer)
    participant D as data-store
    Note over W,D: Precondition: autosave, a lookup, an import, a story, a scene picture, a dialogue delivery, a photo upload or an exercise result is in progress for a collection
    W->>D: reads the collection
    U->>UI: renames, moves, reorders, deletes or erases that collection
    UI->>S: filing change
    S->>D: one transaction writing only filing fields, or the erase
    Note over S,D: persists name, folderId, order, binnedAt, or deletes the record
    W->>D: writes its result, as an update by id or the autosave put
    alt the record exists, in a folder or in the bin
        D-->>W: the result is stored, filing fields kept from the stored record
        Note over W,D: persists only the writer's own fields
    else the record was erased for good
        D-->>W: nothing written, the result is dropped and logged
    end
    Note over U,D: Postcondition: the new name, place and order hold after the work and after a restart, a binned collection stays in the bin
```

### F11 — History (US-11)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant D as data-store
    U->>UI: opens History from the side menu
    UI->>S: list collections with words
    S->>D: read collections with words that are not in the bin, newest first, and the current pointer
    D-->>S: collections and current id
    alt none has words
        S-->>UI: empty list
        UI-->>U: there are no collections yet
    else some
        S-->>UI: rows with name, word count and date
        UI-->>U: each row with name and word count, the date below, the current one marked current
    end
    U->>UI: taps a row
    UI-->>U: that collection's words table
```

### F12 — Share as a link with the name (US-12)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant W as service (Worker)
    participant WD as data-store (Worker)
    participant PG as ui (shared page)
    actor P as user (partner)
    U->>UI: Share on the words table
    UI-->>U: share sheet, warning that the name is visible to anyone with the link
    U->>UI: Share link
    UI->>S: publish the collection
    S->>W: publish words, sources and title, with the edit token on a republish
    alt the title breaks the name rule
        W-->>S: refused
        S-->>UI: the publish failed
    else valid
        W->>WD: store the collection and its title, same page and link on a republish
        Note over W,WD: persists title on the published collection
        W-->>S: the link
        S-->>UI: the link
        UI-->>U: link dialog
    end
    opt a later dialogue or picture delivery
        S->>W: deliver to the same page
        W->>WD: store the delivery, title untouched
    end
    P->>PG: opens the link
    PG->>W: render the page
    W->>WD: read the published collection
    WD-->>W: words and title, or no title for a page published before
    W-->>PG: the title as plain text, or "Vocabulary"
    PG-->>P: the page titled with the name, nothing about folders, other collections or the bin, the name not editable
    Note over U,P: Postcondition: a rename reaches the page only on the next Share link
```

### F13 — Share a file named after the collection (US-13)

```mermaid
sequenceDiagram
    autonumber
    actor U as user (learner)
    participant UI as ui
    participant S as service
    participant X as external-system (share targets)
    U->>UI: Share file, then picks one of the five formats
    UI->>S: make the file
    S->>S: safe file name, each reserved or control character becomes "-", "collection" if nothing is left
    alt PDF
        S->>S: the name is also the PDF heading
    else Anki, CSV, Quizlet, Word list
        S->>S: the name only in the file name and the subject
    end
    S-->>UI: the file and the subject
    UI->>X: hands over the file
    Note over U,X: Postcondition: the collection's own name is unchanged
```

### Coverage (sequences stage)

| User story | Flow(s) |
|---|---|
| US-01 | F1 |
| US-02 | F2 |
| US-03 | F3, design flow 2 |
| US-04 | F4 |
| US-05 | F5 |
| US-06 | F6, F10 |
| US-07 | F1, F10 |
| US-08 | F7 |
| US-09 | F8, F10 |
| US-10 | F9 |
| US-11 | F11 |
| US-12 | F12 |
| US-13 | F13 |
| US-14 | N/A: wording on existing screens, no runtime path (AC-33) |

| AC | Shown by |
|---|---|
| AC-01 | F1 valid branch |
| AC-02 | F1 and F5 rule branches |
| AC-03 | F1 postcondition, F7 default name |
| AC-04 | F4 first-open backfill |
| AC-05 | N/A: title layout (ellipsis, buttons stay visible) is a widget concern, no runtime path |
| AC-06 | F2 top level |
| AC-07 | F2 icons and current mark |
| AC-08 | F2 folders, path, Up |
| AC-09 | F3 another collection |
| AC-10 | F3 already current |
| AC-11 | F3 late result, design flow 2 |
| AC-12 | F4 every branch |
| AC-13 | F5 |
| AC-14 | F6 drop branches, hover-open |
| AC-15 | F6 folder into itself |
| AC-16 | F6 no-op branch |
| AC-17 | F1 item menu |
| AC-18 | F7 |
| AC-19 | F3 and F7 leave branches |
| AC-20 | F8 another collection |
| AC-21 | F8 current refused |
| AC-22 | F8 folder branches |
| AC-23 | F9 list |
| AC-24 | F9 Restore |
| AC-25 | F9 Delete forever or Empty |
| AC-26 | F4 sweep |
| AC-27 | F10, design flow 1 |
| AC-28 | F11 |
| AC-29 | F12 publish and delivery |
| AC-30 | F12 partner |
| AC-31 | F12 share sheet warning |
| AC-32 | F13 |
| AC-33 | N/A: wording only, no runtime path |

**Flags for later stages (not decided here):**
- F12: the Worker refusing a title that breaks the name rule is drawn as a failed publish; `api` fixes the error shape.
- F4: the one-time backfill and the sweep run before the main screen shows; QG-3's 500 ms covers the Collections screen only, but a long first-open backfill should be measured during `ship`.

## 7. Deployment view

The app ships as the same Android build; nothing new runs in the background. The one-time filing backfill and the bin sweep run inside the app when the store opens. The Worker deploys as today with `wrangler deploy` after D1 migration `0007` is applied. Because the column is nullable and the app only adds a field to the publish body, an old app against a new Worker and a new app against an old Worker both keep working (an old Worker ignores the unknown `title`).

**Monitoring:**
- `debugPrint('VOCAB: …')` lines for the backfill (collections named, from collectionId vs fallback), each sweep (items erased), refused bins of the current collection, and dropped late results.
- Worker: the existing `log.ts` line on create/republish gains whether a title came with it. No new alerts: a single-owner app.

**Scaling thresholds:**
- Designed and measured for 300 collections and 50 folders (spec §6). Level renumbering and the ancestor walk are linear in the items of one level and the folder depth, so they stay well under a frame up to thousands of items.
- If the Collections grid misses 500 ms at that size, the first lever is a word count kept on the record, which needs the owner's approval as new data (§11).

## 8. Crosscutting concepts

| Concept | Convention | Where defined |
|---|---|---|
| Logging | `debugPrint('VOCAB: …')`, as the launch rule does today | `word_input_notifier.dart` |
| Error handling | Stores never throw: a bad read answers `null`/`[]`, a failed write is logged and skipped. A refused action (current collection, folder into itself, bad name) returns a result the screen turns into a message | `SessionStore` class doc (→ `CollectionStore`) |
| Authentication | None in the app. A shared link with its edit token is the only credential (unchanged) | `idea-brief.md` §5 |
| ID strategy | Collections keep their time-based `collectionId`; folders get `uuidV4()` from `source_photo_store.dart` | here, ADR-0004 |
| Concurrency | Filing changes, erase and late results are each one Isar write transaction in `CollectionStore`; `put()` never writes filing (it may only raise `keep` to true) and never inserts | ADR-0003, ADR-0006 |
| Time | Bin expiry is `binnedAt + 30 × 24 h` on the phone's clock (a forward-moved clock is trusted, AC-26); "N days left" is 30 minus the calendar days since the day of deletion (local time), never below 1, so it shows 1 until the sweep erases the item; default names use local time | `filing.dart` |
| Internationalisation | None: hardcoded English strings, as today. "session" becomes "collection" in every visible text (AC-33) | — |
| Untrusted text | A name is plain text everywhere: `Text` widgets in the app, `escapeHtml` on the shared page, the file-name replacement of AC-32 in shared files | page.ts, share_formats.dart |
| Navigation | `CollectionsRoute` and `RecycleBinRoute` are typed routes; dialogs and menus stay `showDialog` / popup menus | CLAUDE.md rule 1 |

## 9. Architecture decisions

| # | Title | Status | Section |
|---|---|---|---|
| 0001 | Change the app, the Worker and the shared page as three surfaces | Accepted | §4 |
| 0002 | Rename Session to WordCollection with stored names pinned | Accepted | §4 |
| 0003 | Keep filing on the collection row, written only by store transactions | Accepted | §4 |
| 0004 | Store folders as their own Isar collection linked by parent id | Accepted | §4 |
| 0005 | Mark a deleted item in place and let a binned folder's contents follow it | Accepted | §4 |
| 0006 | Deliver late results into their own collection through an atomic store update | Accepted | §4 |
| 0007 | Reopen the current collection after any pause | Accepted | §4 |
| 0008 | Send the collection name as the shared page's title in a nullable column | Accepted | §4 |

ADR files live under `docs/features/collections-screen/adr/NNNN-<title>.md`.

## 10. Quality requirements

**QG-1. Name and place stability**
- **When:** the learner renames, moves, reorders, deletes or erases for good a collection while background work for it (autosave, translation, photo reading, Quizlet or subtitle import, story, scene picture, dialogue delivery, photo upload, exercise result) finishes.
- **Then:** 0 reverted names, places or orders, and 0 collections coming back from the bin, over 100 scripted runs of rename / move / delete / erase for good while background work for that collection finishes.
- **How verify:** automated test with each background writer: a `CollectionStore` test over a real Isar instance that interleaves each writer's `update`/`put` with each filing transaction, 100 runs, asserting name, folder, order and bin mark after each run and after reopening the store.

**QG-2. Update safety**
- **When:** the owner installs the updated app over their existing data (rename + filing backfill).
- **Then:** 0 words, photos, notes, stories or exercise results lost when moving to the updated app.
- **How verify:** migration test over a copy of the owner's real data: counts before = counts after (words, sources, dialogues, groups, results, tags per collection; story runs; photo files), plus every collection at the top level with a name from its creation moment (AC-04).

**QG-3. Collections screen open time**
- **When:** the learner taps Collections in the side menu with 300 collections and 50 folders stored.
- **Then:** ≤ 500 ms from tapping the menu item to a full icon grid.
- **How verify:** release build on the owner's phone, screen-ready timing in a profile run.

**QG-4. Move durability**
- **When:** a drop, rename, delete or restore is made and the app is force-closed.
- **Then:** a drop, rename, delete or restore survives a force-close made 1 s after it.
- **How verify:** device test: act, wait 1 s, kill the app, reopen, check. Filing writes are not debounced, so the transaction has committed before the screen updates.

**QG-5. Bin retention**
- **When:** an item sits in the recycle bin and the app is opened or resumed at various times, with the clock moved backwards in some runs.
- **Then:** erased no earlier than 30 × 24 h after deletion, and at the first app open after that.
- **How verify:** unit test with a controlled clock, including a clock moved backwards (a clock moved forward is trusted, AC-26), over `filing.dart` expiry and `CollectionStore.sweepBin`.

**QG-6. Drag vs tap**
- **When:** the learner long-presses and drags icons of every kind (onto folders, Up, the path, between icons, the bin zone, empty spots).
- **Then:** 0 collection switches caused by a drag, over 50 scripted drags.
- **How verify:** widget test of long-press drags of every kind, asserting the current-collection pointer after each.

## 11. Risks and technical debt

| Risk / debt | Severity | Mitigation | Owner |
|---|---|---|---|
| A wrong `@Name` pin in the rename makes Isar open an empty collection, and the learner's data looks lost | High | Rename is its own first step (ADR-0002); the QG-2 migration test over a copy of the owner's data runs before any behaviour change ships; the old records are never deleted, so a fixed build reads them again | Maksym |
| A writer added later puts a stale copy and reverts filing, or re-creates an erased collection | High | `put()` ignores filing fields and never inserts (ADR-0003); QG-1 test per writer; a new writer must use `update` (ADR-0006); architecture.md gets the rule | Maksym |
| The rename touches ~98 files and collides with any parallel branch | Medium | Land it first on a quiet master as one mechanical commit; no other feature work in flight meanwhile | Maksym |
| Isar loads every collection's words to draw the grid, and 300 collections miss the 500 ms target | Medium | Measure in a profile build first (QG-3); if it misses, keep a word count on the record, which needs the owner's approval as new data (rule 5) | Maksym |
| Delivering late results into a collection that is no longer current changes import-from-quizlet's "a result for another session is dropped" and edit-session-from-history ADR-0003 | Medium | ADR-0006 supersedes them; tests for each lookup and import that returns after a switch | Maksym |
| A drag conflicts with the grid's scroll or the side menu's edge swipe | Medium | Long press starts a drag only after the finger moves (AC-14); QG-6 widget test; device check during `ship` | Maksym |
| The phone's clock moved forward erases bin items early | Low | Accepted by the spec (AC-26) | Maksym |
| A shared page outlives its erased collection and can no longer be updated | Low | The erase confirmation says so (AC-25); the page expires on its own | Maksym |
| Brownfield drift: architecture.md, the launch-rule tests and edit-session-from-history ADR-0002/0003 describe the 5-minute rule and dropping late results | Low | ADR-0006 and ADR-0007 supersede them; `implement` updates architecture.md and replaces `word_input_launch_rule_test.dart` | Maksym |
| Resolved 2026-10-16 (`sdd:screens`): where a restored item lands in its folder's order (spec §8) | Low | Its old position when it is still within the level, otherwise the end; a binned item keeps its `order` (screens SCR-08) | Maksym |

**Accepted debt (acceptable in v1, plan to fix later):**
- The retired `seen_*` and `switched_*` `shared_preferences` keys are removed once at startup, not migrated.
- Story runs of an erased collection keep their pictures with no way to delete them (spec §8, owner 2026-10-16).
- No word count on the record; the grid counts words from the loaded records until QG-3 says otherwise.

## 12. Glossary

| Term | Meaning |
|---|---|
| collection | A named set of words stored on the learner's phone; one file on the Collections screen. Formerly "session"; stored records, Worker routes and shared links still say session (CONTEXT.md). In code: `WordCollection` |
| current collection | The one collection the main screen is editing; exactly one at a time, changed only by the learner (CONTEXT.md) |
| folder | A named place on the Collections screen holding collections and folders, nested to any depth, only on the phone (CONTEXT.md). In code: `CollectionFolder` |
| recycle bin | Where a deleted collection or folder waits 30 days before it is erased for good, and from where it is restored to its old place (CONTEXT.md) |
| filing | A collection's or folder's name, folder, place in the order and bin mark: the fields only `CollectionStore`'s filing transactions write (ADR-0003). *Not yet in CONTEXT.md* |
| level | The items directly inside one folder, or at the top level, ordered together by `order` |
| kept collection | A collection with `keep` set: made with "New collection", renamed, moved, reordered or given a word. An empty collection that is not kept is erased when the learner leaves it (AC-19). *Not yet in CONTEXT.md* |
| erase for good | Removing an item and its photo files from the phone: Delete forever, Empty recycle bin, or the 30-day sweep |
| bin sweep | The check, on launch and on return to the app, that erases items whose 30 days are up (AC-26) |
| a folder cannot go inside itself | Invariant: a folder is never moved into itself or any folder inside it (AC-15) |
| the current collection cannot be deleted | Invariant: binning the current collection is refused, by the store as well as the screen (AC-21) |
