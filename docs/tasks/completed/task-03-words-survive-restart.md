# Task 03 — Sessions: collected words survive an app restart (v2)

|  |  |
|---|---|
| **Roadmap step** | [#3](../../roadmap.md#steps) |
| **Size** | M (4 steps, one commit each) |
| **Wave** | 2 |
| **Depends on** | task-00 (done) |
| **Blocked on** | — (**D8** resolved: `isar_community` replaces `shared_preferences` as the word store — see [`../roadmap.md#decisions-so-far`](../../roadmap.md#decisions-so-far)) |
| **Unlocks** | task-05 (`Session.isShared` + `sessionId` are the handle the shared link needs) · task-08 (the memorized mark lives on the persisted word) · **task-10** (side menu + History builds on `SessionStore.watchNonEmpty()`) |
| **Files** | `pubspec.yaml` · `lib/core/models/session.dart` (new) · `lib/core/models/word_pair.dart` · `lib/core/models/translation_result.dart` · `lib/core/services/session_store.dart` (new, replaces `word_store.dart`) · `lib/core/providers.dart` · `lib/features/word_input/word_input_notifier.dart` · `lib/features/word_input/word_input_screen.dart` · `lib/features/words_table/words_table_screen.dart` · `test/session_store_test.dart` (new, replaces `test/word_store_test.dart`) · `docs/architecture.md` |
| **Status** | v2 **code complete** (2026-09-20). AC-1..AC-6 green (`flutter test` — 16 tests across `test/session_store_test.dart` and `test/word_input_launch_rule_test.dart`); AC-7..AC-14 are the device pass and are still unticked. v1 (one JSON blob in `shared_preferences`, `5e18846`) is what this replaced; see [History](#history-v1) at the bottom. |

## Why a v2

v1 keeps exactly one list. Every launch restores it, so there is no notion of "the words from last
Tuesday" versus "what I am collecting now", nothing to hang a shared link on (task-05), and the
dots popup + lightning marks are lost on restart because only `{word, translation}` is stored.
v2 introduces a **Session** — a set of words with an identity and timestamps — persisted in
**`isar_community`**, restores the per-word extras, and decides at launch whether the previous session
is still "the current one". The side menu and the History screen that make older sessions
reachable are **task-10**, split out on 2026-09-20 because they are pure UI on top of this store.

## Behaviour (the spec)

### The Session object

```
Session
  sessionId            String     unique, generated on the device (see step 1)
  updatedAt            DateTime   last change to the *content* (words). Task-05 will publish this.
  lastLocalModifiedAt  DateTime   last time THIS device touched the session: any content change,
                                  plus the moment it is restored from the snackbar. Drives the
                                  5-minute rule below.
  isShared             bool       true once a shared link was created (task-05). Always false in v2.
  words                [WordPair] ordered
```

`WordPair` grows the per-row extras that make a restored row look exactly as it did before the
kill (decided 2026-09-20: dots data **and** the lightning "filled" marks):

```
WordPair
  word, translation            as today
  hasTranslationOptions  bool  → screen `_hasTranslationOptions[i]`  (dots solid or not)
  translationOptions     TranslationResult?  → `_translationOptions[i]` (the popup body; stored as JSON)
  wordMarkedFilled       bool  → `_wordMarkedFilled[i]`
  translationMarkedFilled bool → `_translationMarkedFilled[i]`
```

Not persisted, reset to defaults on load: `_isLoadingTranslation`, `_isLoadingWordTranslation`,
`_googleInfoCache`, `_popupControllers`, focus.

### Launch rule (decided 2026-09-20)

Let `prev` be the session recorded as current (pointer `current_session_id` in
`shared_preferences`; if the pointer is missing, the session with the newest `lastLocalModifiedAt`).

1. **No `prev`** (fresh install, or nothing stored) → create a new session, make it current, one
   empty row, focus in Word. No snackbar. Same as today.
2. **`prev` exists and has no non-blank word** → reuse it as current, no snackbar, regardless of
   age. (Otherwise every launch-and-do-nothing would leave an empty session behind.)
3. **`prev` exists, `now - prev.lastLocalModifiedAt < 5 min`** → `prev` is current; all its words
   are shown with their extras restored. No snackbar.
4. **`prev` exists, `≥ 5 min`** → create a **new** session and make it current *immediately*
   (empty list, one blank row). Show a `SnackBar`:

   > **"Words from your last session are saved."** — action button **"RESTORE"**

   (final wording, decided 2026-09-20.)
   - Tap RESTORE → delete the new (still empty) session, make `prev` current again, set
     `prev.lastLocalModifiedAt = now`, show its words. This is `_restoreFromStore` with a different
     source, nothing new in the screen.
   - The snackbar is **not sticky**: `duration: Duration(seconds: 7)`, then it is gone (decided
     2026-09-20). Let it time out / ignore it / start typing → the new session stays current and
     `prev` goes to history. It is also dismissed on the first edit so RESTORE can never discard
     typed words — by construction the new session is empty whenever RESTORE fires.

### Side menu and History

Split out to [`task-10-side-menu-and-history.md`](task-10-side-menu-and-history.md).
This task only has to leave `SessionStore.watchNonEmpty()` and `nonEmpty()` in place for it.

## Prompt

Read `CLAUDE.md`, `docs/architecture.md` and the spec above. Four steps, one commit each; the app
runs after every step. Nothing about the look or animation of rows, the dots popup, the FAB or the
photo flow changes; the only visible addition is the snackbar. The existing Drawer is left exactly
as it is — task-10 replaces it.

### Step 1 — Packages and models

1. `pubspec.yaml` (the owner approved these; D8):
   ```yaml
   dependencies:
     isar_community: ^3.3.2
     isar_community_flutter_libs: ^3.3.2
     path_provider: ^2.1.0      # already imported by words_table_screen.dart as a transitive dep — make it direct
   dev_dependencies:
     isar_community_generator: ^3.3.2
   ```
   `shared_preferences` **stays**: it keeps the `current_session_id` pointer and is the v1 source
   the migration reads from. Run `flutter pub get`; if the resolver rejects a version with the
   current Flutter SDK, stop and write what it said under this step — do not pin something else.

   **DONE, with one deviation from the version numbers above.** `^3.3.2` genuinely cannot resolve
   here, and an earlier attempt read that as "no database at all" and shipped the v2 *shape*
   (`Session`, `SessionStore`) on top of `shared_preferences`. That is now undone — the store is
   real Isar. The workaround is a **version pin**, not a different package:

   ```yaml
   dependencies:
     isar_community: 3.3.0-dev.1
     isar_community_flutter_libs: 3.3.0-dev.1
     path_provider: ^2.1.0
   dev_dependencies:
     isar_community_generator: 3.3.0-dev.1
   ```

   What the resolver actually said, for the record:

   > Because isar_community_generator >=3.3.1 depends on build ^4.0.0 and riverpod_generator
   > <3.0.0-dev.17 depends on build ^2.0.0, isar_community_generator >=3.3.1 is incompatible with
   > riverpod_generator <3.0.0-dev.17.

   `3.3.0-dev.2` and `3.3.0` fail the same way against `build ^3.0.0`; `3.2.0` and below want
   `analyzer ^6.9.0` → `macros` → `_macros from sdk`, which this SDK no longer ships. That leaves
   **`3.3.0-dev.1`** — the last release built on `build 2.x` — as the one version that coexists with
   `riverpod_generator ^2.6.1` and `go_router_builder ^3.0.0`. Pinned exactly (no caret) so
   `pub upgrade` cannot drift onto `3.3.0-dev.2`. The alternative, upgrading riverpod to 3.x, is a
   breaking API change across every provider and is not task-03's to make.

   Two gotchas worth writing down:
   - the import is **`package:isar_community/isar.dart`**, not `.../isar_community.dart` — the
     package kept Isar's original library name, and the wrong path fails as
     `Could not resolve annotation for class Session` rather than as a missing import;
   - `Isar.initializeIsarCore(download: true)` in a test needs the network, and
     `TestWidgetsFlutterBinding` turns every request into a 400. Both test files lift
     `HttpOverrides.global` around that one call.

   `isar: ^3.1.0` (added by the earlier attempt, never actually used) is removed.
2. `lib/core/models/session.dart` (new) — `@collection class Session` exactly as in the spec plus
   `Id id = Isar.autoIncrement;` and `@Index(unique: true) late String sessionId;`. Generate
   `sessionId` as `'${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 32).toRadixString(36)}'`
   in a static `Session.create()` — no `uuid` package. Add `bool get isEmpty => words.every((w) => w.isEmpty)`.
   Isar ignores getters, so `isEmpty` needs no annotation.
3. `lib/core/models/word_pair.dart` — becomes `@embedded`. Isar needs an unnamed constructor with
   no required parameters, so `word` and `translation` get `= ''` defaults; every existing
   `WordPair(word: ..., translation: ...)` call keeps compiling. Add the four extras from the spec.
   `translationOptions` is stored as a `String? translationOptionsJson` field (Isar-visible) with an
   `@ignore TranslationResult? get translationOptions` / setter pair that encodes/decodes it. Do
   not make `TranslationResult` an embedded object — it is Google's shape, and a JSON string
   survives Google changing it. Keep `toJson`/`fromJson` (the migration in step 2 uses them).
4. `lib/core/models/translation_result.dart` — add hand-written `toJson`/`fromJson` to
   `DictionaryWord`, `DictionaryEntry`, `TranslationResult`. Nothing else in the file changes.
5. `dart run build_runner build --delete-conflicting-outputs` → `session.g.dart`, `word_pair.g.dart`
   committed. `flutter analyze` clean.

### Step 2 — `SessionStore` (no v1 migration)

1. `lib/core/services/session_store.dart` (new). One plain class, opened once:
   `SessionStore.open({String? directory})` → `Isar.open([SessionSchema], directory: directory ?? (await getApplicationDocumentsDirectory()).path, name: 'vocab')`.
   API, all `Future`, none of them throw on bad data:
   - `Future<Session?> byId(String sessionId)`
   - `Future<Session?> newest()` — max `lastLocalModifiedAt`
   - `Future<List<Session>> nonEmpty()` — sessions with ≥1 non-blank word, newest first
   - `Future<void> put(Session s)` — upsert on `sessionId`; blank pairs are stripped before write
     (the trailing empty row is still never persisted — v1 AC-5 holds)
   - `Future<void> delete(String sessionId)`
   - `Stream<List<Session>> watchNonEmpty()` — `isar.sessions.where().watch(fireImmediately: true)`
     mapped through the non-empty filter; the drawer rule and the History screen read this.
   - `Future<String?> currentSessionId()` / `Future<void> setCurrentSessionId(String)` — the
     `shared_preferences` pointer (`current_session_id`). Yes, in the same class: it is one concept,
     "which session is current".
2. `lib/core/providers.dart` — replace `wordStoreProvider` with
   `@Riverpod(keepAlive: true) Future<SessionStore> sessionStore(Ref ref) => SessionStore.open();`
   and add `sessionByIdProvider(String sessionId)` (a `FutureProvider.family`, or `@riverpod` with
   a parameter) for the History → table path. Delete `word_store.dart`.
3. `test/session_store_test.dart` (new; delete `test/word_store_test.dart`). Hermetic: Isar in a
   `Directory.systemTemp.createTempSync()` directory, `await Isar.initializeIsarCore(download: true)`
   in `setUpAll` (downloads the native library into the pub cache the first time; note this in
   `docs/tasks/README.md`'s verification table), `SharedPreferences.setMockInitialValues`. Cover
   AC-2..AC-6 below (skip AC-5 which was v1 migration).

### Step 3 — Notifier owns a `Session`; the screen restores the extras

1. `word_input_notifier.dart` — state becomes `AsyncValue<Session>`; `build()` implements the
   launch rule verbatim (cases 1–4). Expose the outcome to the screen without a second provider:
   a nullable field `String? restorableSessionId` on the notifier, set in case 4 only, cleared by
   `restorePrevious()` and by the first mutation. Existing mutators keep their names and
   signatures; `updateAt` gains named optional `hasTranslationOptions`, `translationOptions`,
   `wordMarkedFilled`, `translationMarkedFilled`. Every mutation sets
   `updatedAt = lastLocalModifiedAt = now` and `_scheduleSave()` (500 ms debounce, `flush()` on
   `paused`) — unchanged mechanics, now writing a `Session` through `SessionStore.put`.
   New: `Future<void> restorePrevious()` (delete current empty session, `setCurrentSessionId(prev)`,
   bump `prev.lastLocalModifiedAt`, `state = AsyncData(prev)`).
2. `word_input_screen.dart` — three small changes, nothing rewritten:
   - `_restoreFromStore(List<WordPair>)` also copies the four extras into the parallel lists right
     after `_addControllersForIndex(i)`; the `TranslationResult` goes into `_translationOptions[i]`.
   - Every place that today writes `_hasTranslationOptions[index]`, `_translationOptions[index]`,
     `_wordMarkedFilled[index]` or `_translationMarkedFilled[index]` (the lightning handlers
     around lines 505–575, the controller listeners in `_addControllersForIndex` that reset them,
     the dots-popup selection) additionally pushes the same values through `updateAt`. Grep for
     the four list names; there is no other source of truth.
   - After the first-load `ref.listen`, if `restorableSessionId != null`, show the snackbar from the
     spec: `SnackBar(content: Text('Words from your last session are saved.'), duration: Duration(seconds: 7), action: SnackBarAction(label: 'RESTORE', onPressed: () => ref.read(...notifier).restorePrevious()))`.
     Also `ScaffoldMessenger.hideCurrentSnackBar()` on the first edit (a one-line guard in the
     controller listener).
3. `words_table_screen.dart` — no behaviour change; it now reads `session.words`.

### Step 4 — Docs and the device pass

- `docs/architecture.md`: persistence line in §1 and the diagram in §3 say `SessionStore` /
  `isar_community`; rule 6's package list gains the three Isar packages + `path_provider`.
- `docs/tasks/README.md`: index row for task-03, verification note about `initializeIsarCore(download: true)`.
- `CLAUDE.md` "Before finishing" block is unchanged and must pass.
- Walk AC-7..AC-14 on a real device and tick them here.

## Acceptance criteria

- [x] **AC-1** `dart run build_runner build` clean; `flutter test` passes (25 tests); the three
      greps in `CLAUDE.md` are clean (only the documented `PhotoScaler.instance`). `flutter analyze`
      reports **no new issues** but still exits 1 on 3 pre-existing `prefer_const_constructors`
      infos in `word_row_item.dart`, which arrived with task-04 and are left alone here.
- [x] **AC-2** Store round-trip: `put` a session with 3 words (one with a tab, one with a newline,
      one with a `TranslationResult` holding 2 part-of-speech groups + the four extras set),
      `byId` returns the same session, same order, same characters, extras intact, popup
      dictionary equal group-for-group.
- [x] **AC-3** `put` of a session with 2 filled words + a trailing blank stores 2; `byId` returns 2.
- [x] **AC-4** `newest()` on an empty store returns `null`; `nonEmpty()` returns `[]`; neither throws.
- [x] **AC-5** `nonEmpty()` excludes a session whose words are all blank; `watchNonEmpty()` emits
      once immediately and again after a `put`.
- [ ] **AC-7** On device: enter 4 words, tap lightning on two of them so the dots are solid, open
      a popup to confirm it has groups, force-quit within 5 min, reopen → same 4 rows, same
      lightning icons, the same two dots solid, popup shows the same groups without a network
      call (airplane mode on for the reopen).
- [ ] **AC-8** On device: same as AC-7 but wait > 5 min (or change the device clock) before
      reopening → one blank row + snackbar; ignore it, type a word → snackbar gone; force-quit,
      reopen within 5 min → only the new word. (`nonEmpty()` now returns two sessions — visible
      in History once task-10 lands.)
- [ ] **AC-9** On device: after AC-8, wait > 5 min, reopen, tap RESTORE → the session you were
      just editing (1 word) is shown; the 4-word session is still in the store; no empty session
      was left behind (check with `nonEmpty()` in a debug print, or wait for task-10's History).
- [ ] **AC-10** On device: launch, do nothing, force-quit, launch again (> 5 min apart) → no
      snackbar, and the same `sessionId` is reused (launch rule 2).
- [ ] **AC-11** On device, fresh install: single empty row, focus in Word, no snackbar.
- [ ] **AC-12** On device: in drag mode (the existing drawer item) reorder two rows, delete one,
      force-quit, reopen → order and deletion persisted; no row shows another row's translation or
      another row's dots popup (parallel lists aligned).
- [ ] **AC-13** On device: type a long word quickly, background the app immediately → the last
      characters are there after reopening (debounce flushed on `paused`).
- [ ] **AC-14** The photo flow (`docs/refactoring-plan.md` §"Behaviour that must not change" #5)
      still passes; photo-added words persist with `hasTranslationOptions = false`.

## Open points

None — snackbar wording and 7-second duration, the 5-minute rule, the launch cases and the persisted extras were all
decided on 2026-09-20. Side-menu questions live in task-10.

## Notes from the build (2026-09-20)

- The launch rule has its own test file, `test/word_input_launch_rule_test.dart`: all four cases,
  the extras surviving case 3, RESTORE leaving no empty session behind, the first edit disarming
  RESTORE, and a dangling `current_session_id` falling back to `newest()`.
- `SessionStore.put` no longer mutates the caller's session. The earlier version stripped blanks
  with `s.words.removeWhere(...)`, which deleted the screen's trailing empty row out from under it
  on every debounced save. It now writes a filtered copy.
- The screen pushes per-row state through one funnel, `_pushRow(index, {word, translation})`, which
  sends the text together with all four extras. Every former `updateAt` call site goes through it,
  so there is no path that saves a word without its dots/lightning state.
- `_restoredFromStore` (a bool) became `_restoredSessionId` (a String?): RESTORE swaps one session
  for another, so the screen has to rebuild its rows a second time, and only a session id can tell
  that apart from the screen's own edits.
- `watchNonEmpty()` is a real Isar query watch now (the shared_preferences version was a single
  `yield` with a comment admitting it). task-10 can build on it as planned.

### Fixed after the first device pass — the snackbar could never fire

Reported from the device: the dots/lightning restore worked, the >5-minute snackbar never appeared.
Cause was not in the snackbar or in the launch rule but in **where the timestamps were stamped**.
`flush()` set `updatedAt = lastLocalModifiedAt = now` on the write, and the screen calls `flush()`
from `didChangeAppLifecycleState(paused)` — so backgrounding or force-quitting the app counted as
"this device touched the session". The clock reset on the way out every single time, the next
launch was always inside the 5-minute window, and case 4 was unreachable.

The spec already said where they belong — *"every mutation sets `updatedAt = lastLocalModifiedAt =
now`"* — the mutation, not the write. So:

- `_scheduleSave()` stamps the timestamps, since that is what every mutator calls;
- `flush()` only writes, and is a no-op unless a mutation actually happened (`_dirty`);
- `addAll()` of nothing but blank pairs neither stamps nor saves. `_checkAndAddNewPair` re-adds the
  trailing blank row on every launch and `put` strips it again, so it is not a content change —
  left alone it would have restarted the clock on a launch where the user did nothing.

Two tests in `test/word_input_launch_rule_test.dart` pin it: `flush()` with no edit leaves
`lastLocalModifiedAt` where it was, and a cold session survives a background-then-force-quit still
restorable. Both fail against the old code.

`_showRestoreSnackBar` also stopped going through `addPostFrameCallback` — that callback only runs
if something else schedules a frame, which nothing guarantees on this path.

A widget test through the real `WordInputScreen` was attempted and abandoned: Isar's reads go
through a native port that `testWidgets`' fake async never pumps, so every `await` into the store
hangs, and `runAsync` did not rescue it. The launch rule is covered at the notifier level instead;
the snackbar itself still wants a device check (AC-8, AC-9).

### Found, not fixed — the reorder path's stale closure index

`_addControllersForIndex(int index)` builds each controller listener around the `index` it was
created with, but `_onReorder` moves controllers between list positions without rebuilding them.
So after a drag, typing into a moved row writes to the row it *used* to be — `_wordPairs[index]`
and `updateAt(index, ...)` both take the stale index. This predates task-03 (the old code passed
the same stale index to `updateAt`) and it does not affect AC-12 as written, which reorders and
then force-quits without typing. Fixing it means keying rows by identity instead of position,
which is a rewrite of the screen's per-row state — exactly what `CLAUDE.md` rule 3 says not to do
inside this task. Worth its own task before task-08 leans on row identity.

## History (v1)

v1 shipped as task-00 step 3 (`5e18846`): one JSON list under the `shared_preferences` key
`word_pairs_v1`, restored on every launch. Its ACs 1–8 were verified, 9–11 were not; v2's AC-13,
AC-14 and AC-12 re-check those. The original prompt is kept below because the parallel-lists
warning in its step 4 is still the sharpest description of the screen's per-row state.

### v1 prompt (shared_preferences, done)

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

### v1 acceptance criteria

- [x] **AC-1** `flutter analyze` exits 0; `flutter test test/word_store_test.dart` passes.
- [x] **AC-2** Store round-trip: `save` a list of 3 pairs (one containing a tab and one containing
      a newline — both are plausible in a translation and both break a naive delimited format),
      `load` returns the same 3 pairs in the same order with the same characters.
- [x] **AC-3** `load()` on an empty store returns `[]` and does not throw.
- [x] **AC-4** `load()` over deliberately corrupt stored data (`'not json'`, and valid JSON of the
      wrong shape such as `'{"a":1}'`) returns `[]` and does not throw.
- [x] **AC-5** Blank pairs are not persisted: `save` a list of 2 filled pairs plus the trailing
      blank, and `load` returns 2. (Verified indirectly via AC-6/AC-7 on device — reopening always
      showed exactly 5 rows + one blank, never 6, which is only possible if the trailing blank
      never got persisted.)
- [x] **AC-6 — the behaviour itself.** On device: enter 5 word/translation pairs, force-quit the app
      from the app switcher (not a hot restart), reopen it. All 5 rows are there, in order, with
      both fields populated, plus one empty row at the end. Not two empty rows.
- [x] **AC-7** On device: repeat AC-6 three times in a row without clearing between runs. The list
      stays at 5 filled rows and one blank — no duplication, no growth.
- [x] **AC-8** On device: add rows via a photo capture, force-quit, reopen. The photo-added words
      survived too.
- [ ] **AC-9** On device: delete a row and reorder two others, force-quit, reopen. The order and
      deletion both persisted, and no row shows another row's translation — the parallel lists
      stayed aligned. **Not explicitly checked** — worth doing before relying on this in task-08.
- [ ] **AC-10** On device: type a long word quickly, then immediately background the app. The last
      characters typed are present after reopening (the debounce flushed on `paused`). **Not
      explicitly checked** (skipped as likely redundant with the force-quit tests, which exercise
      the same `paused` -> `flush()` path) — worth a quick check if this ever regresses.
- [ ] **AC-11** On device, fresh install: the app opens to a single empty row with focus in the Word
      field, exactly as before this task. **Not explicitly checked** — logically guaranteed by
      `_restoreFromStore`'s `pairs.isEmpty` guard (never fires on a truly empty store, so
      `initState()`'s single default row stands untouched), but not confirmed on a real fresh
      install.
