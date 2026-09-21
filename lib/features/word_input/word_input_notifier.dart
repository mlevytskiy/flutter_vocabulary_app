import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/session.dart';
import '../../core/models/translation_result.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/session_store.dart';

part 'word_input_notifier.g.dart';

/// How long a session stays "the current one" after this device last touched
/// it. Past this, a launch starts a fresh session and offers the previous one
/// back through the snackbar (see `docs/tasks/task-03-words-survive-restart.md`).
const kSessionIdleWindow = Duration(seconds: 30); // TODO(test): restore to Duration(minutes: 5)

/// Owns the current [Session]. `WordInputScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.
@Riverpod(keepAlive: true)
class WordInputNotifier extends _$WordInputNotifier {
  Timer? _saveTimer;

  /// True between a mutation and the write that persists it. `flush()` is
  /// called on every `AppLifecycleState.paused`, so without this a plain
  /// background-or-force-quit would write — and, worse, re-stamp — a session
  /// nobody edited.
  bool _dirty = false;

  /// Set by [build] only when the launch rule started a new session and an
  /// older one is still worth offering back (case 4). The screen reads it once
  /// to decide whether to show the RESTORE snackbar. Cleared by
  /// [restorePrevious] and by the first mutation, so RESTORE can never discard
  /// typed words.
  String? restorableSessionId;

  @override
  Future<Session> build() async {
    ref.onDispose(() => _saveTimer?.cancel());
    final store = await ref.read(sessionStoreProvider.future);

    // `prev` is the session recorded as current; if the pointer is missing or
    // dangling, the newest session this device touched.
    Session? prev;
    final pointer = await store.currentSessionId();
    if (pointer != null) prev = await store.byId(pointer);
    prev ??= await store.newest();

    // Case 1 — nothing stored: a new session, one empty row, no snackbar.
    if (prev == null) return _startNewSession(store);

    // Case 2 — the previous session never got a word: reuse it whatever its
    // age, otherwise every launch-and-do-nothing leaves an empty session behind.
    if (prev.isEmpty) {
      await store.setCurrentSessionId(prev.sessionId);
      if (prev.words.isEmpty) prev.words = [WordPair()];
      return prev;
    }

    // Case 3 — still warm: carry on in it, extras and all. No snackbar.
    if (DateTime.now().difference(prev.lastLocalModifiedAt) <
        kSessionIdleWindow) {
      await store.setCurrentSessionId(prev.sessionId);
      return prev;
    }

    // Case 4 — gone cold: a new session is current immediately, and the screen
    // offers `prev` back for the next 7 seconds.
    final fresh = await _startNewSession(store);
    restorableSessionId = prev.sessionId;
    return fresh;
  }

  Future<Session> _startNewSession(SessionStore store) async {
    final session = Session.create();
    session.words.add(WordPair());
    await store.put(session);
    await store.setCurrentSessionId(session.sessionId);
    return session;
  }

  /// Drops the (still empty) session the launch rule just created and makes the
  /// previous one current again. Called from the snackbar's RESTORE action.
  Future<void> restorePrevious() async {
    final id = restorableSessionId;
    restorableSessionId = null;
    if (id == null) return;

    final store = await ref.read(sessionStoreProvider.future);
    final prev = await store.byId(id);
    if (prev == null) return;

    final current = state.valueOrNull;
    if (current != null && current.sessionId != id && current.isEmpty) {
      await store.delete(current.sessionId);
    }

    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    prev.lastLocalModifiedAt = DateTime.now();
    await store.setCurrentSessionId(prev.sessionId);
    await store.put(prev);
    state = AsyncData(prev);
  }

  void setPairs(List<WordPair> pairs) {
    if (!state.hasValue) return;
    final session = state.value!;
    session.words
      ..clear()
      ..addAll(pairs);
    state = AsyncData(session);
    _scheduleSave();
  }

  /// Every argument left out keeps its current value. [translationOptions] is
  /// set only when non-null — pass `clearTranslationOptions: true` to drop it,
  /// which is what the screen does whenever the Word field changes.
  void updateAt(
    int i, {
    String? word,
    String? translation,
    bool? hasTranslationOptions,
    TranslationResult? translationOptions,
    bool clearTranslationOptions = false,
    bool? wordMarkedFilled,
    bool? translationMarkedFilled,
  }) {
    if (!state.hasValue) return;
    final session = state.value!;
    if (i < 0 || i >= session.words.length) return;
    final current = session.words[i];
    final next = WordPair(
      word: word ?? current.word,
      translation: translation ?? current.translation,
      hasTranslationOptions:
          hasTranslationOptions ?? current.hasTranslationOptions,
      translationOptionsJson:
          clearTranslationOptions ? null : current.translationOptionsJson,
      wordMarkedFilled: wordMarkedFilled ?? current.wordMarkedFilled,
      translationMarkedFilled:
          translationMarkedFilled ?? current.translationMarkedFilled,
    );
    if (translationOptions != null) next.translationOptions = translationOptions;
    session.words[i] = next;
    state = AsyncData(session);
    _scheduleSave();
  }

  void removeAt(int i) {
    if (!state.hasValue) return;
    final session = state.value!;
    if (i < 0 || i >= session.words.length) return;
    session.words.removeAt(i);
    state = AsyncData(session);
    _scheduleSave();
  }

  void reorder(int oldIndex, int newIndex) {
    if (!state.hasValue) return;
    final session = state.value!;
    if (oldIndex < 0 || oldIndex >= session.words.length) return;
    final pair = session.words.removeAt(oldIndex);
    session.words.insert(newIndex.clamp(0, session.words.length), pair);
    state = AsyncData(session);
    _scheduleSave();
  }

  void addAll(List<WordPair> newPairs) {
    if (!state.hasValue || newPairs.isEmpty) return;
    final session = state.value!;
    session.words.addAll(newPairs);
    state = AsyncData(session);
    // The screen keeps exactly one blank row at the end and `put` strips it, so
    // growing that row is not a content change. Stamping it would restart the
    // session clock on a launch where the user did nothing at all.
    if (newPairs.every((p) => p.isEmpty)) return;
    _scheduleSave();
  }

  /// Records that a shared link now exists for the current session (task-05).
  /// Not a content change: the timestamps are left alone so publishing does
  /// not restart the 5-minute launch clock, and the write goes straight to the
  /// store rather than through the debounce.
  Future<void> markShared() async {
    final session = state.valueOrNull;
    if (session == null || session.isShared) return;
    session.isShared = true;
    state = AsyncData(session);
    final store = await ref.read(sessionStoreProvider.future);
    await store.put(session);
  }

  /// Cancels any pending debounced save and writes immediately. A no-op when
  /// nothing has changed since the last write — see [_dirty]. Blank pairs (the
  /// trailing empty row) are never persisted.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty || !state.hasValue) return;
    _dirty = false;
    final store = await ref.read(sessionStoreProvider.future);
    await store.put(state.value!);
  }

  /// Records that the words just changed and queues the write.
  ///
  /// The timestamps are stamped **here**, at the mutation, not in [flush]. They
  /// have to be: `flush()` also runs on `paused`, so stamping there made every
  /// background or force-quit look like an edit, the session never aged past
  /// the 5-minute window, and the RESTORE snackbar could never fire.
  void _scheduleSave() {
    final session = state.value;
    if (session == null) return;
    final now = DateTime.now();
    session.updatedAt = now;
    session.lastLocalModifiedAt = now;
    // The user has started working in the new session, so the previous one is
    // history now — RESTORE must not be able to throw these words away.
    restorableSessionId = null;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), flush);
  }
}
