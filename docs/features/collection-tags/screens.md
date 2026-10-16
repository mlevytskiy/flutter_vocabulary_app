---
status: approved
feature_size: "L"
tool: "code"
updated_at: "2026-10-16"
---

# Screens — collection-tags

> The canonical **screen manifest** — every screen in every state — read by `tasks`, `implement`
> and `review`. Downstream stages reference **only this manifest**.

## Source

- **Tool:** code. `docs/design-system.md` doesn't exist yet, so this is the default mode, not a degradation.
- **File:** inline wireframes below.
- **Inventory used:** the widgets the app already uses, named by Flutter class or repo file: `AppBar` (+ `bottom` slot), `showModalBottomSheet`, `TextField`, `AlertDialog`, `SnackBar`, `ListView`, `InputChip` / `ActionChip` / `FilterChip`, `RawAutocomplete`, `PopupMenuButton`/`showMenu`, `showDateRangePicker`, `SegmentedButton`/`ChoiceChip`, `FilledButton`, `TextButton`, the existing `TagEditor` (`lib/features/notes/tag_editor.dart`), `NameDialog` (folders only), `CollectionIcon`, and the existing round buttons (Settings, recycle bin, plus) on Collections. New ones are in §New components.
- **Derived from:** [ux-flows.md](./ux-flows.md) SCR-01..SCR-09 + "States worth naming" · spec §5 AC-01..AC-39 · sad §6 Flows 1–9. There is no contracts folder (api N/A).
- **Look:** the app's own style. The top bars keep `topBarColor` (`lib/app.dart`). Only the changes approved for this feature appear (sad §9 CLAUDE.md lines). Everything else stays as it is.
- **Chip look (one everywhere):** compact stadium `TagChip`. Origin tags get `Icons.explore_outlined` with a `secondaryContainer` tint, and topic tags get `Icons.tag` with a `tertiaryContainer` tint (owner batch 1, Q3c).

## Screens

### SCR-01 — Main screen

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default · no tags | The collection has no typed tag (AC-13). | The existing `AppBar` (title, edit button, Next), with an empty `bottom` slot of height 0. Looks exactly as today. | — |
| default · tags | The collection has ≥ 1 typed tag (AC-13). | `AppBar.bottom` = NEW `CollectionTagLine`: one horizontal `ListView` of `TagChip`s (≈ 40 dp), origin chips first, then topic. | wireframe A |
| tag line growing / shrinking | First tag added or last removed (AC-13, owner V8). | `CollectionTagLine` animates its height 0 ↔ 40 dp over ≈ 200 ms. | — |
| covered | The half-open photo panel or its flares overlap the line (owner batch 4). | Unchanged z-order: the panel draws above the AppBar, and taps there go to the panel. | — |
| tag tapped | A chip tap (AC-14). | Pushes SCR-05 with `CollectionsRoute(tagKind, tag)`. | — |
| loading / error / empty | N/A: they are the main screen's existing states and stay unchanged. The tag line reads the in-memory collection. | — | — |

```text
A  default · tags
+------------------------------------------+
| ≡  Friends S01           [✎] [→ Next]    |
| (⌖ Series) (# Everyday life) (# Idioms) →|   ← tag line, scrolls sideways
+------------------------------------------+
|  word            | translation           |
```

### SCR-02 — Collection details sheet

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default · create | New collection on SCR-04 (AC-01, AC-02). | NEW `CollectionDetailsSheet` in `showModalBottomSheet(isScrollControlled)`: title "New collection". Name `TextField` (required, 60), Description `TextField` (multi-line, 500, counter), two NEW `TypedTagField`s (origin, topic), and a `FilledButton` **Create**. | wireframe A |
| default · edit | Edit button on SCR-01 (AC-05). | Same widget, title "Collection details", filled in, button **Save**. | wireframe A |
| empty tag fields | No tags yet (AC-07). | Each `TypedTagField` shows the hint ("Where does it come from?" / "What is it about?"), the helper line ("e.g. Friends (series), a podcast, a trip to London" / "e.g. Food, Phrasal verbs, Job interview") and a suggestion row of up to 8 `ActionChip`s (own tags first, then presets). | wireframe A |
| typing | Text in a tag field (AC-08, AC-35). | `RawAutocomplete` options list: word-start matches, ranked. Confirming text that equals an existing spelling takes that spelling (AC-09). | wireframe B |
| validation · name/description | Name empty or > 60, description > 500 (AC-03). | `errorText` under the field, Create/Save disabled. | — |
| validation · tag | Empty after trim, > 30, multi-line, or an 11th of its kind (AC-04, AC-10). | `errorText` under that tag field: "A tag is 1 to 30 characters on one line" / "At most 10 origin tags" (or topic). The tag is not added. | — |
| over-limit list | A migrated list holds > 10 (AC-17b). | All chips shown and removable. Adding stays refused while there are ≥ 10. | — |
| forget menu | Long-press on an own-tag suggestion or option (AC-12). | SCR-09. | — |
| dismiss with changes | Swipe down, Back or a tap outside after a change (AC-36). | SCR-03. | — |
| saving / error | N/A: store writes don't throw to the UI (sad §8). The sheet closes when the save returns. | — | — |

```text
A  default · create
+------------------------------------------+
|  New collection                           |
|  Name  [Friends S01                    ]  |
|  Description [Season 1 phrases        ]  |
|              [                    17/500] |
|  Where does it come from?                 |
|  (⌖ Series ×)  [type a tag…          ]    |
|  e.g. Friends (series), a podcast, a trip |
|  (Book)(Film)(Podcast)(YouTube)(Song) →   |   ← suggestion row, max 8
|  What is it about?                        |
|  (# Everyday life ×)(# Idioms ×) [……]     |
|  e.g. Food, Phrasal verbs, Job interview  |
|  (Food)(Travel)(Work)(Business)(IT) →     |
|                               [ Create ]  |
+------------------------------------------+

B  typing "co" in the topic field
|  What is it about?   [co|            ]    |
|   ┌───────────────────────────┐          |
|   │ # Cooking                 │          |
|   │ # Home cooking            │          |
|   │ # Conversation (preset)   │          |
|   └───────────────────────────┘          |
```

### SCR-03 — Discard changes dialog

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | Dismissing SCR-02 after a change (AC-36). | `AlertDialog` "Discard changes?" with `TextButton` **Keep editing** and **Discard**. | — |
| no change | N/A: with no change, the sheet closes without the dialog. | — | — |

### SCR-04 — Collections screen — folder view

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | Today's folder window (unchanged), plus two `IconButton`s in the `AppBar` actions: search (`Icons.search`) and filter (`Icons.tune`). | existing grid, `CollectionIcon`, round buttons | wireframe A |
| New collection | Plus → New collection (AC-01). | Opens SCR-02 (create) instead of making the collection straight away. Folders keep `NameDialog`. | — |
| loading / empty / error | N/A: unchanged from collections-screen. | — | — |

```text
A  default
+------------------------------------------+
| ←  Collections                 [🔍] [⚙︎≡] |
+------------------------------------------+
|  [📁 Films]  [📄 Friends S01] [📄 …]      |
```

### SCR-05 — Collections screen — results

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| search entry | Search icon (owner batch 4). | The `AppBar` title becomes a `TextField` with autofocus and keyboard. While the query is empty and no filter is set, the folder view (SCR-04) stays below. | — |
| results | Query or filter active (AC-19, AC-20, AC-20b, AC-37). | Under the AppBar, a row of removable `InputChip`s for active filters (e.g. "⌖ Series", "# Food", "Created: last 30 days") plus a **Clear** `TextButton`. Below it, a `ListView` of NEW `CollectionResultTile`s (icon, name, folder path subtitle, origin/topic `TagChip`s), in the chosen sort. | wireframe A |
| opened from a tag | Tag tap on SCR-01 (AC-14, AC-39). | Same as results with one chip and sort My order. Back pops to SCR-01. | — |
| empty | Nothing matches (AC-24). | Centered "No collections match" with a `FilledButton.tonal` **Clear filters**. | wireframe B |
| drag / delete disabled | Search or filter on (AC-22). | Long-press does nothing, and the delete-mode toggle is not offered. | — |
| loading | First summaries not yet read. | The existing Collections loading look (`CircularProgressIndicator`). | — |
| error | N/A: summary reads skip failures (the `_watchFiling` convention). | — | — |

```text
A  results                                   B  empty
+------------------------------------------+ +------------------------------------------+
| ←  [cook|                    ] [⚙︎≡]      | | ←  [xyz|                     ] [⚙︎≡]      |
| (# Food ×) (Created: 30 days ×)  Clear   | |                                          |
+------------------------------------------+ |        No collections match              |
| 📄 Kitchen talk                          | |        [ Clear filters ]                 |
|    Films / Podcasts                      | |                                          |
|    (⌖ Podcast) (# Food)                  | +------------------------------------------+
| 📄 Cooking club                          |
|    Top level                             |
```

### SCR-06 — Filter sheet

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | Filter icon (AC-20, AC-37, AC-38). | NEW `CollectionsFilterSheet` in `showModalBottomSheet`. Header "Filter" with a **Reset** `TextButton`. "Where it comes from" and "What it's about" sections each have a narrowing `TextField`, `FilterChip`s with counts (first 12 + "Show all"), Created and Edited `ChoiceChip` rows (Any time, Last 7 days, Last 30 days, This year, Custom range…), and a Sort `ChoiceChip` row (My order, Name A–Z, Recently edited, Recently created). A `FilledButton` **Show N collections** with a live N. | wireframe A |
| no tags yet | No live collection has a tag of a kind (AC-38). | That section shows "No tags yet". | — |
| custom range set | After SCR-07 (AC-37). | The chip reads e.g. "1 Oct – 5 Oct". | — |
| N = 0 | No match (owner batch 4). | The button reads "Show 0 collections" and still applies. | — |

```text
A  default
+------------------------------------------+
|  Filter                          Reset   |
|  Where it comes from  [narrow…       ]   |
|  (⌖ Series 4)(⌖ Book 3)(⌖ Podcast 2) …   |
|  What it's about      [narrow…       ]   |
|  (# Food 5)(# Idioms 3) … Show all       |
|  Created  (Any)(7 days)(30 days)(Year)(…)|
|  Edited   (Any)(7 days)(30 days)(Year)(…)|
|  Sort     (My order)(A–Z)(Edited)(Created)|
|                    [ Show 7 collections ]|
+------------------------------------------+
```

### SCR-07 — Date-range picker

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | Custom range… (AC-37). | `showDateRangePicker`, local dates, whole days. | — |
| validation | Start after end (AC-21). | The picker's own validation where it applies. Otherwise a `SnackBar` "Start must be on or before end", and the range is not applied. | — |

### SCR-08 — Notes page

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | Opened from the photo panel (AC-34). | The top "Collection tags" `TagEditor` is replaced by two `TypedTagField`s (origin, topic, compact). Each source note's single tag editor is likewise replaced by two `TypedTagField`s. No description on this page. | wireframe A |
| field focused | A tag field has focus (AC-34). | Its suggestion row and helper line show. Unfocused fields hide them. | — |
| copy-up refused | The collection already has 10 of that kind (AC-29). | `SnackBar` "The collection already has 10 topic tags — not added to it" (or origin), naming each kind once. | — |
| validation | Bad tag (AC-04, AC-10). | `errorText` under the field, as on SCR-02. | — |
| loading / error | N/A: the existing Notes page states are unchanged. | — | — |

```text
A  default (top of the page)
+------------------------------------------+
|  Where does it come from?                 |
|  (⌖ Book ×) [add…                     ]   |
|  What is it about?                        |
|  (# Food ×)(# Idioms ×) [add…        ]    |
+------------------------------------------+
|  [photo]  Page 12 — note …                |
|           origin [add…]  topic (# Restaurants ×) [add…] |
```

### SCR-09 — Forget-tag menu

| State | Trigger / condition | Components | Source-ref |
|---|---|---|---|
| default | Long-press on one of the learner's own tags in a suggestion row or the autocomplete list (AC-12). | `showMenu` anchored on the chip or row, with one item "Forget this tag". | — |
| preset | Long-press on a preset. | N/A: no menu opens. | — |

## New components

| Component | Why no existing primitive fits | Registered in design-system |
|---|---|---|
| `TagChip` (`lib/features/tags/tag_chip.dart`) | One look per kind (icon + tint), shared by four screens. A bare `InputChip` would duplicate the styling everywhere. | pending (no design-system.md yet) |
| `TypedTagField` (`lib/features/tags/typed_tag_field.dart`) | Grows from the existing `TagEditor` (ADR-0007): adds a hint, a helper line, a ranked suggestion row (always shown or only while focused), limit messages and long-press Forget. | pending |
| `CollectionTagLine` (`lib/features/word_input/collection_tag_line.dart`) | An animated, horizontally scrolling `PreferredSize` for `AppBar.bottom`. Nothing like it exists. | pending |
| `CollectionDetailsSheet` (`lib/features/collections/collection_details_sheet.dart`) | `NameDialog` holds one field. The sheet needs four fields plus discard handling. | pending |
| `CollectionResultTile` (`lib/features/collections/collections_results_view.dart`) | A flat row with a folder path and tags. The grid's `CollectionIcon` has no room for either. | pending |
| `CollectionsFilterSheet` (`lib/features/collections/collections_filter_sheet.dart`) | No filter UI exists in the app. | pending |
