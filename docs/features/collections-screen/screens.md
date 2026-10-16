---
status: draft
feature_size: "L"
tool: "code"
updated_at: "2026-10-16"
---

# Screens — collections-screen

> The canonical **screen manifest** — every screen in every state — produced by `screens` (between
> `api` and `tasks`) and read by `tasks` (each `ui` task cites SCR ids + states), `implement`
> (builds the screen to the declared states) and `review` (the built screen must match this).
> Downstream stages reference **only this manifest** — never the raw Figma / `.pen` file.

## Source

- **Tool:** code. There is no `docs/design-system.md` yet, so this is the default mode, not a degradation of a chosen tool. Recommend `/sdd:design-system` (ux-flows "Platform decisions" already asks for it).
- **File:** inline wireframes below.
- **Inventory used:** with no canon, the components are the widgets the app already uses, named by their Flutter class or repo file: `AppBar`, `ElevatedButton.icon` (the main screen's white **Next** button), `Drawer` + `ListTile` (the main screen's side menu), `showDialog` + `AlertDialog` + `TextField`, `SnackBar`, `ListView`, `showModalBottomSheet` (share sheet, share format sheet), `CircularProgressIndicator`, `PopupMenuButton` (item menus), and the shared page's existing `header.title` markup. New ones are listed in §New components.
- **Derived from:** [ux-flows.md](./ux-flows.md) SCR inventory (SCR-06 is not used there, so there is none here) · spec §5 AC-01–AC-33 · sad §6 F1–F13 · [contracts/openapi.yaml](./contracts/openapi.yaml) `title_invalid`.
- **Look:** the app's own style, not a retro Windows 95 one (spec §1, §3). Only the changes approved in spec §1 appear. Everything else on existing screens stays exactly as it is (CLAUDE.md rule 3).

## Screens

### SCR-01 — Main screen

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | The current collection is open (AC-01, AC-12). | `AppBar`: title = the collection's name. The new edit button (pencil icon only, white background, no text, styled like **Next** minus its label) sits beside it, then the existing **Next**. The existing `Drawer` opens from the leading menu icon. | wireframe A |
| long name | The name doesn't fit beside the two buttons (AC-05). | Title `Text` with `maxLines: 1`, `overflow: ellipsis`; the edit button and **Next** keep their full size and stay tappable. | wireframe B |
| default name | The collection was never renamed (AC-03). | The title shows its creation date and time, e.g. "16.10.2026 14:30". | wireframe A |
| loading | First frame while the launch rule reads the store (F4: backfill, bin sweep, pointer). | The existing loading behaviour of the main screen, unchanged. | — |
| empty | A new or empty collection (AC-18). | The existing one blank row, unchanged; the title is still the name. | — |
| restore offer | — | **Removed**: no RESTORE snackbar any more (AC-12, ADR-0007). | — |
| error | N/A: the store never throws (sad §8); a failed rename keeps the old name in SCR-02. | — | — |

```text
A  default                                   B  long name
+------------------------------------------+ +------------------------------------------+
| ≡  Phrasal verbs        [✎] [→ Next]     | | ≡  Speaking club 12 — id… [✎] [→ Next]   |
+------------------------------------------+ +------------------------------------------+
|  word            | translation           |   (✎ and Next never shrink or hide)
|  ...                                     |
```

### SCR-02 — Name dialog

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default · rename | The edit button on SCR-01, or Rename on SCR-05 (AC-01, AC-17). | `AlertDialog`: title "Rename collection" or "Rename folder"; a one-line `TextField` filled with the current name, all text selected; **Cancel** / **Save**. | wireframe A |
| default · new folder | New folder on SCR-04 (AC-13). | Same dialog: title "New folder", empty field; **Cancel** / **Create**. | — |
| validation | Save with an empty name, only spaces, more than 60 characters, or a line break, e.g. pasted (AC-02, contract `title_invalid` rule). | The dialog stays open; the `TextField` error text says "A name must be 1 to 60 characters on one line"; the old name is kept. The field accepts no Enter newline, and pasted line breaks show the error. | wireframe B |
| success | A valid name is saved (F1, F5). | The dialog closes; the new name shows at once on SCR-01 / SCR-04 / SCR-11. | — |
| loading | N/A: one local transaction, no visible wait (QG-4). | — | — |
| cancel | **Cancel**, Back or a tap outside. | The dialog closes; nothing changes. | — |

```text
A  default                                   B  validation
+--------------------------------------+     +--------------------------------------+
| Rename collection                    |     | Rename collection                    |
| [Phrasal verbs______________]        |     | [_____________________________]      |
|                                      |     |  A name must be 1 to 60 characters   |
|               Cancel      Save       |     |  on one line                         |
+--------------------------------------+     |               Cancel      Save       |
                                             +--------------------------------------+
```

### SCR-03 — Side menu

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | The menu icon or an edge swipe on SCR-01, with any number of collections (AC-06). | The existing `Drawer`: the existing header, then `ListTile`s **Main**, **Collections** (new, folder icon), **History**. It is always present: the "only with other sessions" condition is removed. | wireframe |
| photo panel open | The photo panel is open. | The edge swipe stays disabled as today; the menu icon still opens it (unchanged). | — |
| empty / error | N/A: a fixed list of three items. | — | — |

```text
+----------------------+
| Меню                 |
|----------------------|
| ⌂  Main              |
| 🗀  Collections       |
| ⟲  History           |
+----------------------+
```

### SCR-04 — Collections screen

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default · top level | **Collections** in SCR-03 (AC-06, AC-07). | `AppBar` "Collections" with **New folder** and **New collection** actions. NEW `CollectionsPathBar`: path "Collections", Up shown but unavailable. NEW `CollectionsGrid` of NEW `CollectionIcon`s in the learner's order. A folder icon shows its name. A collection icon shows its name (two lines, ellipsis) and "N words"; the current one has a "current" badge. Every icon has a ⋮ button. The recycle bin is always the last icon, has no ⋮, and can't be dragged. | wireframe A |
| default · inside a folder | A tap on a folder icon, or a hold-to-open during a drag (AC-08, AC-14). | The path grows ("Collections › English course › Unit 3"), every part tappable; Up is available. No bin icon inside folders. | wireframe B |
| empty folder | A folder with nothing in it, e.g. right after New folder (AC-13). | The path and Up, plus a centred hint "This folder is empty" over the empty grid area. The `AppBar` actions stay available. | wireframe C |
| loading | Before the level's first read arrives (QG-3: ≤ 500 ms with 300 collections and 50 folders). | The path bar is drawn at once; a centred `CircularProgressIndicator` sits in the grid area. | — |
| dragging | A long press that moves (AC-14). | The icon follows the finger. Valid drop targets highlight: folder icons, Up, path parts, gaps between icons, collection icons. NEW `BinDropZone` appears at the bottom inside folders; at the top level the bin icon itself is the target. | wireframe D |
| hover-open | The dragged item held over a folder for about 1 s (AC-14). | The folder opens on the same screen and the path updates, while the drag goes on. | — |
| item menu | A long press released without moving, or ⋮ (AC-14, AC-17). | SCR-05 opens. | — |
| refused · into itself | A folder dropped onto itself or a folder inside it (AC-15). | The icon springs back; `SnackBar` "A folder cannot go inside itself". | — |
| refused · current | Delete, or a bin drop, on the current collection (AC-21). | Nothing moves; `SnackBar` "The current collection cannot be deleted. Open another collection first." | — |
| current stayed | A folder holding the current collection was deleted (AC-22). | The current collection now sits where the folder was; `SnackBar` "<name> stayed here because it is the current collection." | — |
| no-op drop | Dropped on an empty spot, outside the grid, its own folder's path part or Up, or Up at the top level (AC-16). | Nothing moves or opens; no message. | — |
| error | N/A: the store never throws (sad §8); refusals are the states above. | — | — |

```text
A  top level                                 B  inside a folder
+------------------------------------------+ +------------------------------------------+
| ←  Collections      [+🗀] [+▤]            | | ←  Collections      [+🗀] [+▤]            |
| [↑ Up]  Collections                      | | [↑ Up]  Collections › English course ›   |
|                                          | |         Unit 3                           |
|  🗀 ⋮        🗀 ⋮       ▤ ⋮      ▤ ⋮       | |  ▤ ⋮         ▤ ⋮                         |
| English    Films     Phrasal   16.10.    | | Lesson 3   Lesson 4                      |
| course               verbs    2026 14:30 | | 24 words   18 words                      |
|                      32 words  0 words   | |            [current]                     |
|                      [current]           | |                                          |
|  🗑                                       | |                                          |
| Recycle bin                              | |                                          |
+------------------------------------------+ +------------------------------------------+
  (Up greyed at the top level)

C  empty folder                              D  dragging inside a folder
+------------------------------------------+ +------------------------------------------+
| [↑ Up]  Collections › Unit 4             | | [↑ Up]  Collections › English course     |
|                                          | |  🗀 ⋮ (highlighted)   ▤ ⋮                 |
|          This folder is empty            | |  Unit 3            Lesson 4              |
|                                          | |        ▤ Lesson 3  (follows the finger)  |
|                                          | | +--------------------------------------+ |
|                                          | | |   🗑  Drop here to delete            | |
+------------------------------------------+ | +--------------------------------------+ |
                                             +------------------------------------------+
```

### SCR-05 — Item menu

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | A long press released without moving, or ⋮, on a collection or folder icon (AC-17, AC-20). | `PopupMenuButton` menu anchored to the icon: **Rename**, **Delete**. | wireframe |
| current collection | The menu of the current collection. | Same two items. **Delete** leads to the SCR-04 "refused · current" state (AC-21); it is not hidden, so the learner learns the rule. | — |
| bin icon | N/A: the recycle bin has no menu and no ⋮ (AC-06). | — | — |
| empty / error | N/A: a fixed two-item menu; a refusal shows on SCR-04. | — | — |

```text
  ▤ ⋮ ┌──────────┐
      │ Rename   │
      │ Delete   │
      └──────────┘
```

### SCR-07 — Delete confirmation

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| collection | **Delete** or a bin drop on a non-current collection (AC-20). | `AlertDialog` "Delete "Lesson 3"?" with body "24 words. It goes to the recycle bin for 30 days. Its shared link keeps working."; **Cancel** / **Delete**. | wireframe A |
| folder | **Delete** or a bin drop on a folder without the current collection (AC-22). | Body "3 collections and 1 folder go to the recycle bin with it, for 30 days."; **Cancel** / **Delete**. | — |
| folder with current | The folder holds the current collection (AC-22). | Body adds ""Lesson 4" stays, because it is the current collection. It moves to where this folder is."; **Cancel** / **Delete**. | wireframe B |
| empty / error | N/A: a confirmation; the current collection itself never reaches it (refused on SCR-04, AC-21). | — | — |
| cancel | **Cancel**, Back or a tap outside. | Nothing changes. | — |

```text
A  collection                                B  folder with the current collection
+--------------------------------------+     +--------------------------------------+
| Delete "Lesson 3"?                   |     | Delete "English course"?             |
| 24 words. It goes to the recycle     |     | 3 collections and 1 folder go to the |
| bin for 30 days. Its shared link     |     | recycle bin with it, for 30 days.    |
| keeps working.                       |     | "Lesson 4" stays, because it is the  |
|               Cancel     Delete      |     | current collection. It moves to      |
+--------------------------------------+     | where this folder is.                |
                                             |               Cancel     Delete      |
                                             +--------------------------------------+
```

### SCR-08 — Recycle bin

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | The bin icon on SCR-04 at the top level (AC-23). | `AppBar` "Recycle bin" with an **Empty recycle bin** action. A `ListView` of `ListTile`s, newest deleted first: folder or collection icon, name, and "N days left" (30 on the deletion day, 1 on the last); collections also show "N words"; a ⋮ on each. | wireframe A |
| empty | Nothing in the bin. | Centred text "The recycle bin is empty"; **Empty recycle bin** unavailable. | wireframe B |
| loading | Before the bin's first read arrives. | Centred `CircularProgressIndicator`. | — |
| restored | **Restore** in SCR-09 (AC-24). | The item leaves the list; `SnackBar` "Restored to <folder name or Collections>", so the learner knows where it went. In that folder it takes its old position when it is still within the level, otherwise the end (spec §8, owner 2026-10-16). | — |
| erased | Confirmed in SCR-10 (AC-25). | The item, or every item, leaves the list. | — |
| error | N/A: the store never throws (sad §8). | — | — |

```text
A  default                                   B  empty
+------------------------------------------+ +------------------------------------------+
| ←  Recycle bin        [Empty recycle bin]| | ←  Recycle bin       (Empty unavailable) |
|  ▤  Lesson 2 · 12 words    30 days left ⋮| |                                          |
|  🗀  Old films              7 days left ⋮| |        The recycle bin is empty          |
|  ▤  15.09.2026 10:02        1 day left  ⋮| |                                          |
+------------------------------------------+ +------------------------------------------+
```

### SCR-09 — Bin item menu

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | A tap, long press or ⋮ on a bin item; a collection here never opens (AC-23). | `PopupMenuButton` menu: **Restore**, **Delete forever**. | — |
| empty / error | N/A: a fixed two-item menu. | — | — |

### SCR-10 — Erase confirmation

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| one item | **Delete forever** in SCR-09 (AC-25). | `AlertDialog` "Delete "Lesson 2" forever?" with body "This cannot be undone. Its words and photos are erased from the phone."; **Cancel** / **Delete forever**. | wireframe |
| one item with a shared link | The collection, or one inside the folder, was published (AC-25). | Body adds "Its shared page stays online until it expires, and can no longer be updated from the app." | wireframe |
| empty / error | N/A: a confirmation; Empty is unavailable when the bin is empty (SCR-08). | — | — |
| empty the bin | **Empty recycle bin** on SCR-08 (AC-25). | Title "Empty the recycle bin?", body "N items are erased for good. This cannot be undone.", plus the shared-page sentence when any of them was published; **Cancel** / **Empty**. | — |
| cancel | **Cancel**, Back or a tap outside. | Nothing changes. | — |

```text
+--------------------------------------+
| Delete "Lesson 2" forever?           |
| This cannot be undone. Its words and |
| photos are erased from the phone.    |
| Its shared page stays online until   |
| it expires, and can no longer be     |
| updated from the app.                |
|          Cancel     Delete forever   |
+--------------------------------------+
```

### SCR-11 — History

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | **History** in SCR-03 (AC-28). | The existing `ListView` rows, newest first. Each row has the name as its title and "N words" beside it, the date below (today's date text), and the existing "current" mark. Binned and empty collections are not listed. | wireframe |
| empty | No collection outside the bin has words (AC-28, AC-33). | The existing empty text, reworded "No collections yet". | — |
| loading | Unchanged existing behaviour. | — | — |
| error | N/A: the store never throws. | — | — |

```text
+------------------------------------------+
| ←  History                               |
|  Phrasal verbs              32 words     |
|  16.10.2026 14:30           current      |
|  Speaking club 12           24 words     |
|  15.10.2026 19:05                        |
+------------------------------------------+
```

### SCR-12 — Share sheet

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | **Share** on SCR-13 (AC-31). | The existing `showModalBottomSheet` with **Share file** and **Share link** and its public-page warnings. New sentence beside them: "The collection's name, "<name>", is visible to anyone with the link." | wireframe |
| publishing | **Share link** tapped. | The existing progress behaviour, unchanged. | — |
| link published | The publish succeeded (F12). | The existing link dialog, unchanged. | — |
| error | The publish failed, including the contract's `title_invalid`, which the app's own check makes unreachable in practice (F12). | The existing publish-failure message, unchanged. | — |

```text
+------------------------------------------+
|  Share file                              |
|  Share link                              |
|  A web page anyone with the link can read|
|  … existing warnings …                   |
|  The collection's name, "Speaking club   |
|  12", is visible to anyone with the link.|
+------------------------------------------+
```

### SCR-13 — Words table

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | **Next** on SCR-01, or a row on SCR-11. | Unchanged. This feature only changes what Share leads to (SCR-12, SCR-15). | — |
| other states | N/A: no state of the words table changes. | — | — |

### SCR-14 — Shared page

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default · named | A page published with a title (AC-29, contract `getSessionPage`). | The existing `header.title` `<h1>` and the document `<title>` show the name; both layouts keep their structure. | wireframe |
| default · before this feature | `title` is NULL (AC-29). | "Vocabulary", exactly as today. | — |
| markup in the name | The name holds `<b>` or similar (spec §6.1). | Shown as literal text through `escapeHtml`. | — |
| long name | 60 characters on a 320 px phone. | The `h1` wraps; the short meta line moves below it, as the existing `flex-wrap` header already does. No sideways scroll. | — |
| gone | Expired or unknown link. | The existing "This word list is gone" page, unchanged. | — |

```text
+------------------------------------------+
| Speaking club 12      24 words · until … |
| [Download for AnkiDroid] [Learn] …       |
|  # | word | translation | …              |
+------------------------------------------+
```

### SCR-15 — Share format sheet

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | **Share file** on SCR-12 (AC-32). | The existing sheet with the five formats, unchanged. | — |
| file made | A format is picked (AC-32, F13). | No visible change on the sheet. The phone's share target receives a file named after the collection (`\ / : * ? " < > \|` and control characters → "-", "collection" if nothing is left), and the subject is the name. A PDF also has the name as its heading. | — |
| error | Unchanged existing behaviour. | — | — |

### Not in the ux-flows inventory

| Screen | State | Why it is here | Components |
|---|---|---|---|
| Words settings → Story runs (existing) | run of an erased collection | sad §5, spec §8 (resolved 2026-10-16): the run stays listed, marked "from a deleted collection", and its pictures stay. ux-flows has no SCR id for it, which is a **noted gap**; ux-flows should add one on its next pass. | The existing run row with a secondary line "From a deleted collection". |

## New components

| Component | Why no existing primitive fits | Registered in design-system |
|---|---|---|
| `CollectionIcon` | No icon tile exists in the app. Lists use `ListTile`, but the folder window needs an icon with a name, a word count, a current badge, a ⋮ button, and long-press-drag behaviour (`LongPressDraggable` + `DragTarget`) in one tile. | pending (no design-system.md yet) |
| `CollectionsGrid` | Lays the icons of one level out in the learner's order, with drop gaps between icons for reordering (AC-14). No grid with drop gaps exists. | pending |
| `CollectionsPathBar` | Up plus a tappable path whose parts are also drop targets (AC-08, AC-14, AC-16). The app has no breadcrumb. | pending |
| `BinDropZone` | The bin target shown only while dragging inside a folder (AC-14). Nothing like it exists. | pending |
| `NameDialog` | One `AlertDialog` + `TextField` with the 1–60 characters, one line rule, shared by SCR-01, SCR-04 and SCR-05 (sad §5 `name_dialog.dart`). It is a composition of existing primitives, registered so the rule lives once. | pending |
