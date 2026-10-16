import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/dialogues/dialogue_rules.dart';
import '../../core/models/film_dialogue.dart';
import '../../core/models/session.dart';
import '../../core/models/session_source.dart';
import '../../core/models/translation_result.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/session_store.dart';
import '../../core/services/source_photo_store.dart' show uuidV4;

part 'word_input_notifier.g.dart';

/// How long a session stays "the current one" after this device last touched
/// it. Past this, a launch starts a fresh session and offers the previous one
/// back through the snackbar (see `docs/tasks/task-03-words-survive-restart.md`).
const kSessionIdleWindow = Duration(minutes: 5);

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
    // A History pick (edit-session-from-history, ADR-0002) only counts for the
    // session the pointer names, never for the newest-session fallback.
    final pickedAt =
        prev == null ? null : await store.switchedAt(prev.sessionId);
    prev ??= await store.newest();
    // Isar hands back embedded lists as fixed-length; the screen grows this one
    // (its trailing blank row), so give it a growable copy.
    if (prev != null) {
      prev.words = prev.words.toList();
      prev.sources = prev.sources.toList();
    }

    // Case 1 — nothing stored: a new session, one empty row, no snackbar.
    if (prev == null) {
      debugPrint('VOCAB: launch case 1, nothing stored: new session');
      return _startNewSession(store);
    }

    // Case 2 — the previous session never got a word: reuse it whatever its
    // age, otherwise every launch-and-do-nothing leaves an empty session behind.
    if (prev.isEmpty) {
      debugPrint('VOCAB: launch case 2, previous session ${prev.sessionId} '
          'has no word: reused, no snackbar');
      await store.setCurrentSessionId(prev.sessionId);
      if (prev.words.isEmpty) prev.words = [WordPair()];
      return prev;
    }

    // Case 3 — still warm: carry on in it, extras and all. No snackbar. A
    // recent pick from History keeps it warm too.
    var touched = prev.lastLocalModifiedAt;
    if (pickedAt != null && pickedAt.isAfter(touched)) touched = pickedAt;
    if (DateTime.now().difference(touched) < kSessionIdleWindow) {
      debugPrint('VOCAB: launch case 3, previous session ${prev.sessionId} '
          'edited or picked ${DateTime.now().difference(touched).inSeconds} s ago: '
          'carried on, no snackbar');
      await store.setCurrentSessionId(prev.sessionId);
      return prev;
    }

    // Case 4 — gone cold: a new session is current immediately, and the screen
    // offers `prev` back for the next 7 seconds.
    debugPrint('VOCAB: launch case 4, previous session ${prev.sessionId} '
        'edited ${DateTime.now().difference(prev.lastLocalModifiedAt).inMinutes} min ago: '
        'new session, RESTORE offered');
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
    prev.words = prev.words.toList(); // growable, see build()
    prev.sources = prev.sources.toList();

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

  /// Makes a session picked on the History words screen the current one
  /// (edit-session-from-history, ADR-0001). The left session is saved first so
  /// a word typed within the save delay is kept, and dropped if it never got a
  /// word. The pick is recorded beside the pointer; the picked session's edit
  /// times are left alone (ADR-0002). Returns false, touching nothing, when
  /// the picked session is not in the store.
  Future<bool> switchTo(String sessionId) async {
    final store = await ref.read(sessionStoreProvider.future);
    final picked = await store.byId(sessionId);
    if (picked == null) return false;
    picked.words = picked.words.toList(); // growable, see build()
    picked.sources = picked.sources.toList();

    await flush();
    final current = state.valueOrNull;
    if (current != null &&
        current.sessionId != sessionId &&
        current.isEmpty) {
      await store.delete(current.sessionId);
    }

    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    await store.setCurrentSessionId(picked.sessionId);
    await store.setSwitched(picked.sessionId, DateTime.now());
    restorableSessionId = null;
    state = AsyncData(picked);
    return true;
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
  /// which is what the screen does whenever the Word field changes. The
  /// definition fields follow the same rules (definition-mode, ADR-0003); a
  /// row's definition is never dropped by an update that does not name it, and
  /// neither is its photo link: [sourceId] sets it, `clearSourceId: true`
  /// drops it (good-looking-web T17).
  void updateAt(
    int i, {
    String? word,
    String? translation,
    bool? hasTranslationOptions,
    TranslationResult? translationOptions,
    bool clearTranslationOptions = false,
    bool? wordMarkedFilled,
    bool? translationMarkedFilled,
    String? definition,
    String? definitionOptionsJson,
    bool clearDefinitionOptions = false,
    bool? definitionMarkedFilled,
    String? sourceId,
    bool clearSourceId = false,
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
      definition: definition ?? current.definition,
      definitionOptionsJson: clearDefinitionOptions
          ? null
          : definitionOptionsJson ?? current.definitionOptionsJson,
      definitionMarkedFilled:
          definitionMarkedFilled ?? current.definitionMarkedFilled,
      sourceId: clearSourceId ? null : sourceId ?? current.sourceId,
      // An edited row is the same row: its groups and dialogues follow it.
      rowId: current.rowId,
    );
    if (translationOptions != null) {
      next.translationOptions = translationOptions;
    }
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

  /// Keeps the film dialogues of a subtitle import whose [keptCount] words
  /// were just added at the end of the session (get-words-from-subtitles-
  /// improvment AC-03, AC-10): each is linked to those rows only, loses the
  /// words the learner removed, is dropped when none is left, and goes after
  /// the session's existing dialogues. In a session with a shared link they
  /// wait to be appended to it (ADR-0005). Called right after the words are
  /// added, so the same debounced write saves both.
  void addImportDialogues(List<ImportedDialogue> dialogues, int keptCount) {
    if (!state.hasValue || keptCount <= 0) return;
    final session = state.value!;
    final filled = [for (final w in session.words) if (!w.isEmpty) w];
    final rows = filled.sublist(max(0, filled.length - keptCount));
    for (final w in rows) {
      if (w.rowId.isEmpty) w.rowId = uuidV4();
    }
    final kept = atDone(dialogues, rows);
    if (kept.isEmpty) return;
    if (session.publishedId != null && session.editToken != null) {
      final importId = uuidV4();
      for (final d in kept) {
        d
          ..importId = importId
          ..importRowIds = [for (final w in rows) w.rowId]
          ..pushState = PushState.pending;
      }
    }
    session.dialogues = [...session.dialogues, ...kept];
    state = AsyncData(session);
    _scheduleSave();
  }

  /// Records that a scene run drew the picture of the dialogue [dialogueId]
  /// (get-words-from-subtitles-improvment AC-14). Not an edit of the words:
  /// the timestamps stay and the write goes straight to the store, as in
  /// [markShared].
  Future<void> setScenePicture(String dialogueId, String runId) async {
    final session = state.valueOrNull;
    if (session == null) return;
    final dialogue = session.dialogues.where((d) => d.id == dialogueId).firstOrNull;
    if (dialogue == null || dialogue.scenePictureRunId == runId) return;
    dialogue.scenePictureRunId = runId;
    // A shared session's page gets the picture too (ADR-0005).
    if (session.publishedId != null && session.editToken != null) {
      dialogue.picturePushState = PushState.pending;
    }
    state = AsyncData(session);
    final store = await ref.read(sessionStoreProvider.future);
    await store.put(session);
  }

  /// Records a photo just kept for this session (good-looking-web T17). The
  /// screen calls it before adding the rows recognised from it, so the rows
  /// never point at a photo the session does not list.
  void addSource(SessionSource photo) {
    if (!state.hasValue) return;
    final session = state.value!;
    session.sources.add(photo);
    state = AsyncData(session);
    _scheduleSave();
  }

  /// Adds the Quizlet set the kept words came from (import-from-quizlet
  /// ADR-0005) and returns its source id, `quizlet-<setId>`. A set the
  /// session already lists keeps its place and takes the newer [name] and
  /// [url] ("one set, one source", AC-13b); a new one goes after the
  /// existing sources. The screen calls it before adding the rows, so the
  /// rows never point at a source the session does not list.
  String upsertSetSource(String setId, String name, String url) {
    final id = 'quizlet-$setId';
    if (!state.hasValue) return id;
    final session = state.value!;
    final existing = session.sources.where((s) => s.id == id).firstOrNull;
    if (existing != null) {
      existing
        ..name = name
        ..url = url;
    } else {
      session.sources.add(SessionSource()
        ..id = id
        ..takenAt = DateTime.now()
        ..kind = SourceKind.set
        ..name = name
        ..url = url);
    }
    state = AsyncData(session);
    _scheduleSave();
    return id;
  }

  /// Adds the film or episode whose subtitles the kept words came from
  /// (side-panel-sources, spec AC-22) and returns its source id. A film the
  /// session already lists under the same [title] keeps its place and its id,
  /// so importing it again adds the new rows to the same source; a new one
  /// goes after the existing sources. The screen calls it before adding the
  /// rows, so the rows never point at a source the session does not list.
  /// [poster] is the film's poster address, kept as the source's `url` for
  /// the photo panel's tile; a film listed without one gets it on a later
  /// import (owner, 2026-10-15).
  String upsertSubtitlesSource(String title, {String? poster}) {
    final session = state.valueOrNull;
    final existing = session?.sources
        .where((s) => s.kind == SourceKind.subtitles && s.name == title)
        .firstOrNull;
    if (existing != null) {
      if (existing.url == null && poster != null) {
        existing.url = poster;
        state = AsyncData(session!);
        _scheduleSave();
      }
      return existing.id;
    }
    final id = 'subtitles-${uuidV4()}';
    if (session == null) return id;
    session.sources.add(SessionSource()
      ..id = id
      ..takenAt = DateTime.now()
      ..kind = SourceKind.subtitles
      ..name = title
      ..url = poster);
    state = AsyncData(session);
    _scheduleSave();
    return id;
  }

  /// Changes the note of the source [id] (notes-editing, owner 2026-10-15).
  /// Every argument left out keeps its value; an empty title or description
  /// is dropped.
  void updateSourceNote(
    String id, {
    String? title,
    String? description,
    List<String>? links,
    List<String>? tags,
  }) {
    final session = state.valueOrNull;
    final source = session?.sources.where((s) => s.id == id).firstOrNull;
    if (source == null) return;
    if (title != null) source.title = title.trim().isEmpty ? null : title;
    if (description != null) {
      source.description = description.trim().isEmpty ? null : description;
    }
    if (links != null) source.links = [...links];
    if (tags != null) source.tags = [...tags];
    state = AsyncData(session!);
    _scheduleSave();
  }

  /// Sets the current session's own tags (notes-editing).
  void setSessionTags(List<String> tags) {
    final session = state.valueOrNull;
    if (session == null) return;
    session.tags = [...tags];
    state = AsyncData(session);
    _scheduleSave();
  }

  /// Puts [pair] at [index] of the words (the Notes words dialog adds a word
  /// right after its source's rows). The main screen does not see this until
  /// it takes [takeEditedElsewhere].
  void insertAt(int index, WordPair pair) {
    final session = state.valueOrNull;
    if (session == null) return;
    session.words.insert(index.clamp(0, session.words.length), pair);
    state = AsyncData(session);
    _scheduleSave();
  }

  /// The words were changed from outside the main screen (the Notes words
  /// dialog), so its rows must be built again from the session.
  bool _editedElsewhere = false;

  void markEditedElsewhere() => _editedElsewhere = true;

  /// True once after [markEditedElsewhere]; the main screen asks when Notes
  /// closes.
  bool takeEditedElsewhere() {
    final edited = _editedElsewhere;
    _editedElsewhere = false;
    return edited;
  }

  /// Records that a shared link now exists for the current session (task-05),
  /// and the published id and edit token a republish sends back (ADR-0008).
  /// Not a content change: the timestamps are left alone so publishing does
  /// not restart the 5-minute launch clock, and the write goes straight to the
  /// store rather than through the debounce.
  Future<void> markShared({String? publishedId, String? editToken}) async {
    final session = state.valueOrNull;
    if (session == null) return;
    if (session.isShared &&
        session.publishedId == publishedId &&
        session.editToken == editToken) {
      return;
    }
    session
      ..isShared = true
      ..publishedId = publishedId
      ..editToken = editToken;
    state = AsyncData(session);
    final store = await ref.read(sessionStoreProvider.future);
    await store.put(session);
  }

  /// Records how far the dialogues' delivery to the shared link got
  /// (get-words-from-subtitles-improvment ADR-0005): [change] gets the
  /// dialogues as they are now. Not a content change, so written like
  /// [markShared].
  Future<void> updateDialogues(
      List<FilmDialogue> Function(List<FilmDialogue>) change) async {
    final session = state.valueOrNull;
    if (session == null) return;
    session.dialogues = change(session.dialogues);
    state = AsyncData(session);
    final store = await ref.read(sessionStoreProvider.future);
    await store.put(session);
  }

  /// Records that a publish carried the dialogues in [sent]
  /// (get-words-from-subtitles-improvment ADR-0005): see [afterPublish]. Not
  /// a content change, so written like [markShared].
  Future<void> markDialoguesPublished(Set<String> sent) async {
    final session = state.valueOrNull;
    if (session == null || session.dialogues.isEmpty) return;
    session.dialogues = afterPublish(session.dialogues, sent: sent);
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
    // Dialogues follow their words in the same save (get-words-from-
    // subtitles-improvment AC-11, AC-26); links only shrink.
    if (session.dialogues.isNotEmpty) session.dialogues = afterEdit(session);
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
