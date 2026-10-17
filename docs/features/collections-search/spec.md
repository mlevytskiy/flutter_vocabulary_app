---
status: Reviewed
owner: "Maksym (learner, app owner)"
updated_at: "2026-10-17"
feature_size: "M"
---

# Spec — collections-search

> Short spec (owner, 2026-10-17: "short spec, then build"). The design was agreed on the
> mockup page https://claude.ai/artifact/GJBATjCMJ3YYGHBGTrQvyd (idea 4's filter sheet, the
> "Folders" section). Builds on collection-tags (search, filter sheet, flat results).

## 1. Context

The Collections search (collection-tags SCR-05) ignores the open folder: it lists matches from
every folder in one flat list, folders are never results, and the filter sheet's tag counts do
not change as filters combine, so a learner can pick a combination that gives nothing.

## 2. Goals

- The list shows what matches **where the learner is**; matches deeper or elsewhere are one drag
  away, with the route to each.
- The filter sheet never lets the learner walk into a dead end without seeing it coming.
- The top bar stays quiet outside search.

## 3. Non-goals

- Voice input (owner, 2026-10-17: left out for now; the keyboard's microphone works).
- Smart folders / saved searches (would need a new stored model).
- Quick-filter chips under the field (idea 1), typeahead tag tokens (idea 2).

## 4. Acceptance criteria

### AC-01 — the filter belongs to search
Outside search the top bar has the title and the search icon only. The filter icon shows while
the search field is open, and also while a filter is on without the field (a tag tap from the
main screen), so the filter can always be changed or seen.

### AC-02 — the hint says where
The search field's hint is "Search in <folder name>" inside a folder and "Search collections" at
the top level.

### AC-03 — the list is this level
While a search or filter is on, the list shows only what matches **directly** in the open folder
(at the top level: collections with no folder): first a "Folders" section with the folders
directly here whose name contains the query, then the matching collections in the chosen sort.
Folder results appear only when the query is not empty and no tag or time filter is on (folders
have no tags or times). Binned folders and folders inside them are never results.

### AC-04 — tapping a folder result narrows
Tapping a folder result opens that folder and keeps the query and the filter.

### AC-05 — Match outside peeks
When any match is not directly in the open folder, a sheet titled "Match outside" shows at the
bottom at about 20% of the screen. Its header says how many are **deeper** (in a folder under the
open one; at the top level every folder is deeper) and how many are **elsewhere** ("5 deeper,
2 elsewhere", zero parts left out), and lists the folders they are in, each with its path. With
no match outside the open folder there is no sheet. While the sheet shows, the three round
buttons are hidden so they do not cover it.

### AC-06 — the route
Dragged up (or its header tapped) the sheet opens to about three quarters of the screen and
shows the route: the folder tree from "Collections" down, pruned to the branches that lead to a
match outside, drawn with connecting lines. The open folder is on it, marked "You are here";
matches deeper hang under it. A folder whose own name matches says "Folder name matches".
Dragging down or tapping the header again goes back to the peek.

### AC-07 — the route is navigation
Tapping a folder on the route (or "Collections") opens it and keeps the query and the filter.
Tapping a collection opens it, as a result tap does.

### AC-08 — empty here, the sheet opens itself
When nothing matches directly here but something matches outside, the list says "Nothing directly
in <place> matches" (place = the folder's name or "the top level") with how many were found
deeper and elsewhere; when nothing is deeper either it says "Nothing in <folder> or its
subfolders matches". The sheet then opens by itself, once per open folder and search: dragging
it back keeps it down until the folder, the query or the filter changes. When nothing matches
anywhere the existing "No collections match" with "Clear filters" shows, and no sheet.

### AC-09 — live counts in the filter sheet
Each tag chip's number is how many collections match the sheet's current draft (the search text,
the picked tags and times) and carry that tag. The chips keep their order (most used overall
first). A chip that is not picked and has 0 is disabled. "Show N collections" counts every match,
in every folder.

### AC-10 — what stays
Back still clears the search first and leaves the folder open; from a tag tap Back still pops to
the main screen. No drag, reorder or delete mode while searching (collection-tags AC-22).

## 5. Tests

`test/collection_search_scope_test.dart` (split, counts, route — pure), `test/collections_search_test.dart`
(AC-01–AC-08, AC-10), `test/collections_filter_sheet_test.dart` (AC-09).
