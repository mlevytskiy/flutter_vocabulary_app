# Task 03 — Collected words survive an app restart

|  |  |
|---|---|
| **Roadmap step** | [#3](../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 2 (parallel with task-02 — app files vs Worker, disjoint) |
| **Depends on** | — |
| **Blocked on** | — |
| **Unlocks** | task-08 (the memorized mark needs a local store to live in) |
| **Files** | `lib/services/` (new store) · `lib/models/word_pair.dart` · `lib/screens/word_input_screen.dart` · `lib/main.dart` · `pubspec.yaml` · `test/` |
| **Status** | not started |

## Prompt

The word list is in-memory only. `_wordPairs` is a plain `List<WordPair>` initialized inline at
`lib/screens/word_input_screen.dart:33`, so killing the app loses every word collected in the
session. Make the list durable: whatever is on screen when the app dies is there when it comes
back.

There is no persistence dependency in `pubspec.yaml` today, so this task picks one. Recommended:
**`shared_preferences` with a single JSON-encoded key**. The data is one small ordered list of
`{word, translation}` pairs with no querying, no relations and no migration history — a database
is more machinery than the shape needs, and `shared_preferences` is already a transitive dependency
of the Flutter plugins in use. If you disagree, use `sqflite` or `hive` and say why in the commit
message; the rest of this prompt holds either way.

Do the following:

1. **Give `WordPair` serialization.** Add `toJson` / `fromJson` to `lib/models/word_pair.dart`.
   Keep it hand-written — the model is two mutable strings and does not justify a codegen
   dependency.
2. **Write a store service.** New `lib/services/word_store.dart`, following the shape the existing
   services use (a plain class, an exception type, no singleton unless it needs one — compare
   `lib/services/vocab_photo_service.dart`). It needs `Future<List<WordPair>> load()` and
   `Future<void> save(List<WordPair> pairs)`. `load()` must return an empty list — never throw —
   when the key is absent (first launch) or the stored JSON is corrupt; a store that crashes the
   app on launch because of a bad write is worse than one that loses a session.
3. **Do not persist the trailing empty row.** `_checkAndAddNewPair()`
   (`lib/screens/word_input_screen.dart:268`) keeps exactly one blank `WordPair` at the end of the
   list at all times, as the row the user types into next. Filter blank pairs on save (`WordPair`
   already has an `isEmpty` getter) and let `_checkAndAddNewPair` re-create the trailing blank
   after load. Skip this and every restart appends another empty row.
4. **Restore on launch.** Load in `initState` and rebuild the row state from what comes back. This
   is the part that will bite: a row is not just a `WordPair`, it is an index into **ten parallel
   lists plus a Map** — `_wordControllers`, `_translationControllers`, `_isLoadingTranslation`,
   `_isLoadingWordTranslation`, `_hasTranslationOptions`, `_translationMarkedFilled`,
   `_wordMarkedFilled`, `_wordFocusNodes`, `_translationFocusNodes`, `_googleInfoCache`, and
   `_popupControllers` (a `Map`). Restoring must call `_addControllersForIndex` for every loaded
   row so all of them grow in lockstep; anything shorter is a `RangeError` the first time the UI
   indexes into it. Read `_ensureRowStateSynced`'s doc comment — it exists because this exact class
   of bug already happened once during hot reload.
   - The transient per-row flags (`_isLoadingTranslation`, `_googleInfoCache`) are **not**
     persisted; they reset to their defaults on load. The "filled" marks
     (`_translationMarkedFilled`, `_wordMarkedFilled`, `_hasTranslationOptions`) drive which
     lightning icons show, per `docs/lightning_icon_rules.md` — decide whether they persist too. If
     they do not, a restored row with a long translation still reads as "filled" via the
     >5-character rule, which is probably good enough; say which you chose.
   - The current `initState` requests focus on the first field after the first frame. With rows
     restored, decide where focus lands — recommended: the trailing empty row, so typing continues
     where the session left off.
5. **Save on change, not on exit.** The app is killed by the OS (Android does it while the camera is
   in the foreground — see `_pollForLostPhoto`'s comment), so there is no reliable "closing" hook.
   Save whenever the list changes: the controller listeners in `_addControllersForIndex`, row
   add/delete, reorder, and after a photo result is added. Those listeners fire **per keystroke** —
   debounce (~500ms) so typing does not hammer the disk, and flush the pending save on
   `didChangeAppLifecycleState(AppLifecycleState.paused)`, which is the last callback you are
   guaranteed to get.
6. **Test the store.** `test/word_store_test.dart`. Note `test/`'s only existing file is a
   live-network smoke test explicitly marked "run manually, not in CI" — this one should be the
   opposite: fast, hermetic, no network. `shared_preferences` ships
   `SharedPreferences.setMockInitialValues({})` for exactly this.

## Acceptance criteria

- [ ] **AC-1** `flutter analyze` exits 0; `flutter test test/word_store_test.dart` passes.
- [ ] **AC-2** Store round-trip: `save` a list of 3 pairs (one containing a tab and one containing
      a newline — both are plausible in a translation and both break a naive delimited format),
      `load` returns the same 3 pairs in the same order with the same characters.
- [ ] **AC-3** `load()` on an empty store returns `[]` and does not throw.
- [ ] **AC-4** `load()` over deliberately corrupt stored data (`'not json'`, and valid JSON of the
      wrong shape such as `'{"a":1}'`) returns `[]` and does not throw.
- [ ] **AC-5** Blank pairs are not persisted: `save` a list of 2 filled pairs plus the trailing
      blank, and `load` returns 2.
- [ ] **AC-6 — the behaviour itself.** On device: enter 5 word/translation pairs, force-quit the app
      from the app switcher (not a hot restart), reopen it. All 5 rows are there, in order, with
      both fields populated, plus one empty row at the end. Not two empty rows.
- [ ] **AC-7** On device: repeat AC-6 three times in a row without clearing between runs. The list
      stays at 5 filled rows and one blank — no duplication, no growth.
- [ ] **AC-8** On device: add rows via a photo capture, force-quit, reopen. The photo-added words
      survived too.
- [ ] **AC-9** On device: delete a row and reorder two others, force-quit, reopen. The order and
      deletion both persisted, and no row shows another row's translation — the parallel lists
      stayed aligned.
- [ ] **AC-10** On device: type a long word quickly, then immediately background the app. The last
      characters typed are present after reopening (the debounce flushed on `paused`).
- [ ] **AC-11** On device, fresh install: the app opens to a single empty row with focus in the Word
      field, exactly as before this task.
