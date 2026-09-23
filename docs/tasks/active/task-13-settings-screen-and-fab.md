# Task 13 — A Settings screen, and the drag-and-drop option moves into it

|  |  |
|---|---|
| **Roadmap step** | [#13](../../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 1 (after task-11 and task-12 — all three touch `word_input_screen.dart`) |
| **Depends on** | **task-11**, **task-12** (same screen file; serialized by file conflict) |
| **Blocked on** | **D9** — where the settings entry point goes (see below; the task proceeds on the recommendation) |
| **Unlocks** | — (it is the first place a future preference has to live, so it unblocks nothing today) |
| **Files** | `lib/router/routes.dart` · `lib/features/settings/settings_screen.dart` (new) · `lib/features/word_input/word_input_screen.dart` · `lib/features/word_input/widgets/word_input_speed_dial.dart` · `docs/architecture.md` |
| **Status** | not started |

## The report

> We should create settings FAB button in the English Vocabulary screen and left bottom corner of
> options (near the "take photo" and "screenshot" button). When we click on settings we should show
> settings screen. And we should move their drag and drop options (remove it from top bar).

Three things: an entry point, a screen, and a move.

## What is already there

Half of this exists and should be finished rather than rebuilt:

- `WordInputSpeedDial` already carries a **third child with `Icons.settings` and an empty `onTap`
  marked "Placeholder for future feature"** (`word_input_speed_dial.dart:47-54`). The "settings
  button near take photo and screenshot" the owner describes is that child.
- The AppBar's drag-and-drop toggle is an `IconButton(Icons.drag_indicator)` with
  `tooltip: 'Drag and Drop мод'`, toggling `_isDragMode` (`word_input_screen.dart:1029-1038`). It
  was moved *into* the AppBar by task-10, one step ago, as a deliberate visible change.

So "move their drag and drop options" reads naturally as: the **mode toggle** moves to Settings, and
the AppBar loses the `IconButton`. That is the reading this task takes.

**Read the "left bottom corner" literally?** The speed dial renders bottom-right (Flutter's
`floatingActionButton` default). Interpretations:

- **(a) Add the settings action to the existing speed dial, leave the FAB where it is.** The child
  already exists; the change is wiring `onTap` and a route. No layout change.
- **(b) Move the whole speed dial to the bottom-left** so it sits in the corner named, which moves
  `take photo` and `screenshot` too — a visible change to two shipped actions.
- **(c) Keep the speed dial bottom-right and add a **separate** settings FAB pinned bottom-left, so
  the owner's "bottom-left corner" is literal and the existing actions do not move.

**Recommended: (c).** It honours the corner that was asked for, and it is the only option that
satisfies "a settings FAB button" and "near the take photo and screenshot button" without moving
anything the owner did not ask to move. It reads as slightly redundant next to the speed dial's own
settings child; if that bothers you, delete the speed-dial child and keep the corner FAB as the only
entry point. Record the choice in `docs/roadmap.md` as **D9** before starting — the decision changes
the acceptance criteria, not just the layout.

## Blocked on D9

> Where the settings entry point lives: the existing speed dial's third child (a), the speed dial
> moved to the bottom-left (b), or a separate bottom-left FAB beside the untouched speed dial (c)?

The task proceeds on (c). If the answer is (a), drop steps 3 and 6 and the criteria that mention the
corner FAB; if (b), add "the two shipped actions still work from their new corner" to the criteria.

## Prompt

Read `CLAUDE.md`, `docs/architecture.md` (rules 1-3 cover this task almost entirely), and
task-10's spec for how the drag toggle got into the AppBar. One commit.

1. **A route, typed, like every other one.** `SettingsRoute` at `/settings`, declared inside the
   existing `@TypedGoRoute<WordInputRoute>` block in `lib/router/routes.dart`, next to `table` and
   `history`. No `Navigator.push`, no string path — rule 1. It is a plain pushed screen, not a
   dialog: it will grow preferences, and the router already carries three screens.
2. **The screen.** `lib/features/settings/settings_screen.dart`, a `ConsumerWidget` (or a
   `StatelessWidget` if nothing on it needs `ref` yet). `AppBar` titled `Settings`, matching the
   other screens' plain style. Its first and only row for now: a `SwitchListTile` for drag-and-drop
   mode, labelled in the same register as the existing tooltip (`Drag and Drop мод`).
3. **The state has to leave the widget.** `_isDragMode` is today a `State` field on the input screen
   (`word_input_screen.dart:76`). A `Switch` on a different screen cannot reach a field on a
   `State` object that is not even mounted — rule 2 of `docs/architecture.md` puts *transient*
   widget state in `State`, but this stops being transient the moment a second screen writes it.
   Promote it to a `@riverpod` notifier in `lib/core/providers.dart` (a tiny
   `Notifier<bool>`/`@riverpod` bool is enough) and have both screens read it. **Do not** put it on
   `Session` or anywhere Isar-backed: it is a display preference, not session data, and that would
   drag in a schema change for nothing.
4. **Rewire the three readers on the input screen** to the provider: the `ReorderableListView`
   branch, the `_buildRowItem` / `WordRowItem(isDragMode:)` argument, and the
   `_reorderItems` path. The reorder mechanics themselves do not change — this is a
   source-of-truth swap, not a reorder rewrite.
5. **Remove the AppBar `IconButton`** and its `tooltip`. The AppBar then holds only the "Next"
   button. Say so in the commit message — it is a visible change the owner asked for, and it
   reverses part of task-10.
6. **The entry point.** Build the choice from D9. If (c): a small `FloatingActionButton` (or
   `FloatingActionButton.small`) for `Icons.settings` in a `Positioned`/`Align` at the bottom-left
   of the screen's `Stack`, above the list, calling `const SettingsRoute().go(context)`. Keep the
   speed dial's own placeholder child consistent with whatever you choose — a settings entry that
   leads nowhere is worse than no entry.
7. **`docs/architecture.md`** — the `features/` tree gains `settings/`, and §3's diagram gains a
   `SettingsScreen` node with the edge that actually carries the state (the preference provider),
   not a decorative one.

## Acceptance criteria

- [ ] **AC-1** `flutter analyze` exits 0; `dart run build_runner build --delete-conflicting-outputs`
      clean (the new provider generates); `flutter test` passes; the three greps in `CLAUDE.md` are
      clean — in particular no `Navigator.push` and no string route path.
- [ ] **AC-2** On device: the settings entry point opens a `Settings` screen and Back returns to the
      input screen with the word list, the current session and the scroll position intact.
- [ ] **AC-3** On device: flipping the drag-and-drop switch in Settings and returning, the list is in
      reorder mode — rows have their drag handles. Flipping it off removes them.
- [ ] **AC-4** On device: the drag-and-drop toggle is **gone from the AppBar**; the AppBar shows
      only the title and "Next".
- [ ] **AC-5** On device: reordering still works end to end in the new mode — drag a row, and the
      same reorder survives a relaunch (task-03's persistence path is untouched by this task).
- [ ] **AC-6** On device: the mode is read from one place — entering Settings, toggling, backing out,
      and re-entering Settings shows the switch in the state it was left in, without a relaunch.
- [ ] **AC-7** On device: the settings entry point is where D9 said it would be, and `take photo` and
      `screenshot` behave exactly as they did before this task (including their animation).
- [ ] **AC-8** The word rows' rendering in either mode is unchanged — same heights, same handles,
      same everything except which control sets the flag.
- [ ] **AC-9** Nothing about drag mode is written to Isar or to `Session`; killing and relaunching
      the app is not required to change the mode, and the mode is not expected to survive a relaunch
      unless D9 says it must.

## Open points

- Whether a display preference should survive a relaunch. Today `_isDragMode` resets to off on every
  launch and nothing asks for it to persist; if it should, that is `shared_preferences` (already a
  dependency, already the home of the `current_session_id` pointer) and one more acceptance
  criterion.
- What else belongs on the Settings screen. Nothing else is queued, so this task ships one row and a
  screen built to take more.
- If D9 lands on the speed dial's existing child instead of a corner FAB, whether the third child
  should get a label (`Settings`) like its two siblings have.
