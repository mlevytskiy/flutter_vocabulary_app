# Task 10 — Side menu and History: reach older sessions

|  |  |
|---|---|
| **Roadmap step** | [#3](../roadmap.md#steps) (second half — split from task-03 on 2026-09-20) |
| **Size** | S |
| **Wave** | 3 (after task-03; disjoint from task-04/05/08 except `routes.dart`, which gains one route) |
| **Depends on** | **task-03 v2** — `Session`, `SessionStore.watchNonEmpty()`, `sessionByIdProvider` |
| **Blocked on** | — |
| **Unlocks** | task-05 can put its "shared" badge on the History rows |
| **Files** | `lib/router/routes.dart` · `lib/features/word_input/word_input_screen.dart` · `lib/features/history/history_screen.dart` (new) · `lib/features/words_table/words_table_screen.dart` · `lib/core/providers.dart` · `docs/architecture.md` |
| **Status** | **code complete 2026-09-22** — AC-1 green (`flutter analyze` 0, `build_runner` clean, `flutter test` 36 passing, the three greps clean). AC-2..AC-8 are the device pass and are still unticked. See [Findings](#findings-2026-09-22) |

## Behaviour (the spec)

### Side menu (decided 2026-09-20)

The existing `Drawer` (`Головний екран` / `Drag and Drop мод`) is **replaced**:

- Items become **Main** (this screen, `selected` when on it) and **History** (`HistoryRoute`).
- The drawer exists only when there is at least one *other* non-empty session besides the current
  one (`Scaffold.drawer: hasOtherSessions ? Drawer(...) : null`). With a single session there is
  no drawer and no hamburger. Set `automaticallyImplyLeading: true` so the hamburger appears when
  the drawer exists (today it is `false` and the drawer is swipe-only — flag this in the commit
  message, it is a visible change the owner approved).
- **Drag-and-drop mode moves to an `IconButton(Icons.drag_indicator)` in the `AppBar` actions**,
  left of the "Next" button, toggling `_isDragMode` (highlighted when on). This is the one
  deliberate look change in this task; the list rendering in either mode is untouched.

### History screen

`lib/features/history/history_screen.dart`, route `/history`. A plain `ListView` of all non-empty
sessions, newest `lastLocalModifiedAt` first: subtitle = date/time of `updatedAt`, title = word
count ("12 words"), trailing "current" chip for the active session (a "shared" badge is task-05's).
Tapping a row opens `WordsTableRoute(sessionId: ...)` — the **existing** `WordsTableScreen`, which
already is read-only and already has the share button; it now reads its words from
`sessionByIdProvider(sessionId)` when a `sessionId` is passed and from the notifier (current
session) when it is not. The AppBar "Next" button keeps calling `const WordsTableRoute().go(context)`
with no id. No editing of past sessions in v2.

## Prompt

Read `CLAUDE.md`, `docs/architecture.md`, and task-03's spec for `Session`/`SessionStore`. One
commit. The list rendering, rows, popup, FAB and photo flow do not change; the visible changes are
exactly the four named above (drawer rule, drawer items, drag icon, History screen).

1. `routes.dart` — add `HistoryRoute` (`/history`) and give `WordsTableRoute` an optional
   `sessionId` query param (`const WordsTableRoute({this.sessionId})`; path stays `table`). IDs
   only, per rule 1.
2. `word_input_screen.dart` — `drawer:` per the spec (watch `sessionStore.watchNonEmpty()` through
   a small `@riverpod` stream provider `otherSessionsExist`), `automaticallyImplyLeading: true`,
   the two new `ListTile`s (Main → `Navigator.pop`, History → `const HistoryRoute().go(context)`),
   the drag-mode `IconButton` in `actions` before "Next". Remove the two old tiles.
3. `lib/features/history/history_screen.dart` — as in the spec; a `ConsumerWidget` over the same
   stream provider. Tapping → `WordsTableRoute(sessionId: s.sessionId).go(context)`.
4. `words_table_screen.dart` — if `widget.sessionId != null` read `sessionByIdProvider`, else the
   notifier. Share button unchanged.
5. `docs/architecture.md` — the `features/` tree gains `history/`; §3 diagram gains
   `HistoryScreen -> sessionStore.watchNonEmpty()`.

## Acceptance criteria

- [x] **AC-1** `flutter analyze` exits 0; `dart run build_runner build` clean; `flutter test`
      passes; the three greps in `CLAUDE.md` are clean (`Navigator.pop` for closing the drawer is
      not `Navigator.push` and is fine).
- [ ] **AC-2** On device, fresh install: single empty row, focus in Word, **no hamburger, no
      drawer on swipe**.
- [ ] **AC-3** On device: with one session only, the drag icon in the AppBar toggles reorder mode
      (highlighted when on); reorder works exactly as it did from the old drawer item.
- [ ] **AC-4** On device: create a second session (enter words, wait > 5 min, reopen, ignore the
      snackbar, type a word) → hamburger appears; drawer shows Main (selected) and History.
- [ ] **AC-5** On device: History lists both sessions newest first with word counts and a
      "current" chip on the active one; no empty session is listed.
- [ ] **AC-6** On device: tap the older session → the words table shows its words; Share produces
      the same TSV it produces for the current session; back returns to History; Main returns to
      the input screen with the current session and its rows intact.
- [ ] **AC-7** On device: AppBar "Next" still opens the table for the *current* session
      (`WordsTableRoute()` with no id).
- [ ] **AC-8** On device: RESTORE from the task-03 snackbar (which deletes the empty new session)
      hides the drawer again when only one non-empty session remains.

## Open points

- Whether History should also list the current session (spec says yes, with a "current" chip).
- Where the drag icon sits if the AppBar gets crowded by task-05's "Publish" action — left of
  "Next" for now.

## Findings (2026-09-22)

Steps 1-5 are implemented. Two deviations from the prompt, both deliberate:

1. **The provider is `nonEmptySessions`, not `otherSessionsExist`.** The prompt named a boolean
   provider, but the History screen needs the session *list* from the same stream, and a second
   provider over the same `watchNonEmpty()` would have meant two subscriptions. So
   `lib/core/providers.dart` exposes `Stream<List<Session>> nonEmptySessions`, and the input screen
   derives `hasOtherSessions` from it locally (`sessions.any((s) => s.sessionId != current)`). Same
   behaviour, one stream.
2. **A History row uses `.push(context)`, not `.go(context)`.** The prompt said `.go`, but `go`
   replaces the stack, so Back from the table would have gone to the input screen rather than to
   History — AC-6 requires "back returns to History". `push` is the typed-route method on
   `GoRouteData`, so rule 1 is intact (no `Navigator.push`, no string path). The drawer's History
   item still uses `.go`, and the AppBar "Next" button still uses `const WordsTableRoute().go(...)`
   with no id, as specified.

Two things outside this task's scope were also fixed, because AC-1 covers the whole repo:

- **`kSessionIdleWindow` was left at `Duration(seconds: 30)`** with a `TODO(test): restore to
  Duration(minutes: 5)` from task-03. Two tests in `test/word_input_launch_rule_test.dart` seed a
  session aged between those values and assert the launch reuses it, so they were failing before
  this task started. Restored to the documented 5 minutes; all 36 tests pass.
- **Three `prefer_const` infos in `word_row_item.dart`** (task-04's drag handle). Pure `const`
  additions on an already-const subtree, no visual or behavioural effect.

`markShared()` is now called only when `sessionId == null`. It stamps whatever session the notifier
holds, so publishing from a History row would otherwise have flagged the *current* session instead
of the one being shared. Publishing itself is unchanged.

Not verified: AC-2 through AC-8, which all need a device. Also unverified is how the drawer behaves
the moment a second session first becomes non-empty, since `watchNonEmpty()` re-emits on write and
the hamburger should appear without a restart.
