import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/dialogues/dialogue_rules.dart';
import '../../core/models/film_dialogue.dart';
import '../../core/models/word_collection.dart';
import '../../core/models/session_source.dart';
import '../../core/models/translation_result.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/collection_store.dart';
import '../../core/services/source_photo_store.dart' show uuidV4;

part 'word_input_notifier.g.dart';

/// Owns the current [WordCollection]. `WordInputScreen` keeps mirroring the words into
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

  @override
  Future<WordCollection> build() async {
    ref.onDispose(() => _saveTimer?.cancel());
    final store = await ref.read(collectionStoreProvider.future);
    await store.sweepBin(DateTime.now());
    return _openCurrent(store);
  }

  /// The launch and resume rule (collections-screen ADR-0007): the pointer's
  /// collection reopens after any pause. A missing or binned pointer (directly
  /// or through a folder) falls back to the newest collection outside the bin,
  /// or a new one when there is none.
  Future<WordCollection> _openCurrent(CollectionStore store) async {
    WordCollection? target;
    final pointer = await store.currentCollectionId();
    if (pointer != null) {
      target = await store.byId(pointer);
      if (target != null && await store.isBinned(target)) target = null;
    }
    target ??= await store.newestOutsideBin();
    if (target == null) {
      debugPrint('VOCAB: launch: nothing usable stored, new collection');
      return _startNewCollection(store);
    }
    // Isar hands back embedded lists as fixed-length; the screen grows this one
    // (its trailing blank row), so give it a growable copy.
    target.words = target.words.toList();
    target.sources = target.sources.toList();
    if (target.words.isEmpty) target.words = [WordPair()];
    debugPrint('VOCAB: launch: collection ${target.collectionId} reopened');
    await store.setCurrentCollectionId(target.collectionId);
    return target;
  }

  Future<WordCollection> _startNewCollection(CollectionStore store) async {
    final collection = await store.create();
    collection.words = [WordPair()];
    await store.setCurrentCollectionId(collection.collectionId);
    return collection;
  }

  /// The app came back to the front: sweep the bin and re-check the pointer.
  /// The collection on screen stays unless it was erased or binned meanwhile.
  Future<void> resume() async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.sweepBin(DateTime.now());
    final current = state.valueOrNull;
    if (current == null) return;
    final stored = await store.byId(current.collectionId);
    if (stored != null && !await store.isBinned(stored)) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    state = AsyncData(await _openCurrent(store));
  }

  /// Makes a session picked on the History words screen the current one
  /// (edit-session-from-history, ADR-0001). The left session is saved first so
  /// a word typed within the save delay is kept, and dropped if it never got a
  /// word. The picked session's edit times are left alone. Returns false, touching nothing, when
  /// the picked session is not in the store.
  Future<bool> switchTo(String collectionId) async {
    final store = await ref.read(collectionStoreProvider.future);
    final picked = await store.byId(collectionId);
    if (picked == null) return false;
    picked.words = picked.words.toList(); // growable, see build()
    picked.sources = picked.sources.toList();

    await flush();
    final current = state.valueOrNull;
    if (current != null &&
        current.collectionId != collectionId &&
        current.isEmpty) {
      await store.delete(current.collectionId);
    }

    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    await store.setCurrentCollectionId(picked.collectionId);
    state = AsyncData(picked);
    return true;
  }

  void setPairs(List<WordPair> pairs) {
    if (!state.hasValue) return;
    final collection = state.value!;
    collection.words
      ..clear()
      ..addAll(pairs);
    state = AsyncData(collection);
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
    final collection = state.value!;
    if (i < 0 || i >= collection.words.length) return;
    final current = collection.words[i];
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
    collection.words[i] = next;
    state = AsyncData(collection);
    _scheduleSave();
  }

  void removeAt(int i) {
    if (!state.hasValue) return;
    final collection = state.value!;
    if (i < 0 || i >= collection.words.length) return;
    collection.words.removeAt(i);
    state = AsyncData(collection);
    _scheduleSave();
  }

  void reorder(int oldIndex, int newIndex) {
    if (!state.hasValue) return;
    final collection = state.value!;
    if (oldIndex < 0 || oldIndex >= collection.words.length) return;
    final pair = collection.words.removeAt(oldIndex);
    collection.words.insert(newIndex.clamp(0, collection.words.length), pair);
    state = AsyncData(collection);
    _scheduleSave();
  }

  void addAll(List<WordPair> newPairs) {
    if (!state.hasValue || newPairs.isEmpty) return;
    final collection = state.value!;
    collection.words.addAll(newPairs);
    state = AsyncData(collection);
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
    final collection = state.value!;
    final filled = [for (final w in collection.words) if (!w.isEmpty) w];
    final rows = filled.sublist(max(0, filled.length - keptCount));
    for (final w in rows) {
      if (w.rowId.isEmpty) w.rowId = uuidV4();
    }
    final kept = atDone(dialogues, rows);
    if (kept.isEmpty) return;
    if (collection.publishedId != null && collection.editToken != null) {
      final importId = uuidV4();
      for (final d in kept) {
        d
          ..importId = importId
          ..importRowIds = [for (final w in rows) w.rowId]
          ..pushState = PushState.pending;
      }
    }
    collection.dialogues = [...collection.dialogues, ...kept];
    state = AsyncData(collection);
    _scheduleSave();
  }

  /// Records that a scene run drew the picture of the dialogue [dialogueId]
  /// (get-words-from-subtitles-improvment AC-14). Not an edit of the words:
  /// the timestamps stay and the write goes straight to the store, as in
  /// [markShared].
  Future<void> setScenePicture(String dialogueId, String runId) async {
    final collection = state.valueOrNull;
    if (collection == null) return;
    final dialogue = collection.dialogues.where((d) => d.id == dialogueId).firstOrNull;
    if (dialogue == null || dialogue.scenePictureRunId == runId) return;
    dialogue.scenePictureRunId = runId;
    // A shared session's page gets the picture too (ADR-0005).
    if (collection.publishedId != null && collection.editToken != null) {
      dialogue.picturePushState = PushState.pending;
    }
    state = AsyncData(collection);
    final store = await ref.read(collectionStoreProvider.future);
    await store.put(collection);
  }

  /// Records a photo just kept for this session (good-looking-web T17). The
  /// screen calls it before adding the rows recognised from it, so the rows
  /// never point at a photo the session does not list.
  void addSource(SessionSource photo) {
    if (!state.hasValue) return;
    final collection = state.value!;
    collection.sources.add(photo);
    state = AsyncData(collection);
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
    final collection = state.value!;
    final existing = collection.sources.where((s) => s.id == id).firstOrNull;
    if (existing != null) {
      existing
        ..name = name
        ..url = url;
    } else {
      collection.sources.add(SessionSource()
        ..id = id
        ..takenAt = DateTime.now()
        ..kind = SourceKind.set
        ..name = name
        ..url = url);
    }
    state = AsyncData(collection);
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
    final collection = state.valueOrNull;
    final existing = collection?.sources
        .where((s) => s.kind == SourceKind.subtitles && s.name == title)
        .firstOrNull;
    if (existing != null) {
      if (existing.url == null && poster != null) {
        existing.url = poster;
        state = AsyncData(collection!);
        _scheduleSave();
      }
      return existing.id;
    }
    final id = 'subtitles-${uuidV4()}';
    if (collection == null) return id;
    collection.sources.add(SessionSource()
      ..id = id
      ..takenAt = DateTime.now()
      ..kind = SourceKind.subtitles
      ..name = title
      ..url = poster);
    state = AsyncData(collection);
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
    final collection = state.valueOrNull;
    final source = collection?.sources.where((s) => s.id == id).firstOrNull;
    if (source == null) return;
    if (title != null) source.title = title.trim().isEmpty ? null : title;
    if (description != null) {
      source.description = description.trim().isEmpty ? null : description;
    }
    if (links != null) source.links = [...links];
    if (tags != null) source.tags = [...tags];
    state = AsyncData(collection!);
    _scheduleSave();
  }

  /// Sets the current session's own tags (notes-editing).
  void setCollectionTags(List<String> tags) {
    final collection = state.valueOrNull;
    if (collection == null) return;
    collection.tags = [...tags];
    state = AsyncData(collection);
    _scheduleSave();
  }

  /// Puts [pair] at [index] of the words (the Notes words dialog adds a word
  /// right after its source's rows). The main screen does not see this until
  /// it takes [takeEditedElsewhere].
  void insertAt(int index, WordPair pair) {
    final collection = state.valueOrNull;
    if (collection == null) return;
    collection.words.insert(index.clamp(0, collection.words.length), pair);
    state = AsyncData(collection);
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
    final collection = state.valueOrNull;
    if (collection == null) return;
    if (collection.isShared &&
        collection.publishedId == publishedId &&
        collection.editToken == editToken) {
      return;
    }
    collection
      ..isShared = true
      ..publishedId = publishedId
      ..editToken = editToken;
    state = AsyncData(collection);
    final store = await ref.read(collectionStoreProvider.future);
    await store.put(collection);
  }

  /// Records how far the dialogues' delivery to the shared link got
  /// (get-words-from-subtitles-improvment ADR-0005): [change] gets the
  /// dialogues as they are now. Not a content change, so written like
  /// [markShared].
  Future<void> updateDialogues(
      List<FilmDialogue> Function(List<FilmDialogue>) change) async {
    final collection = state.valueOrNull;
    if (collection == null) return;
    collection.dialogues = change(collection.dialogues);
    state = AsyncData(collection);
    final store = await ref.read(collectionStoreProvider.future);
    await store.put(collection);
  }

  /// Records that a publish carried the dialogues in [sent]
  /// (get-words-from-subtitles-improvment ADR-0005): see [afterPublish]. Not
  /// a content change, so written like [markShared].
  Future<void> markDialoguesPublished(Set<String> sent) async {
    final collection = state.valueOrNull;
    if (collection == null || collection.dialogues.isEmpty) return;
    collection.dialogues = afterPublish(collection.dialogues, sent: sent);
    state = AsyncData(collection);
    final store = await ref.read(collectionStoreProvider.future);
    await store.put(collection);
  }

  /// Cancels any pending debounced save and writes immediately. A no-op when
  /// nothing has changed since the last write — see [_dirty]. Blank pairs (the
  /// trailing empty row) are never persisted.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty || !state.hasValue) return;
    _dirty = false;
    final store = await ref.read(collectionStoreProvider.future);
    await store.put(state.value!);
  }

  /// Records that the words just changed and queues the write.
  ///
  /// The timestamps are stamped **here**, at the mutation, not in [flush]. They
  /// have to be: `flush()` also runs on `paused`, so stamping there made every
  /// background or force-quit look like an edit, a session
  /// looked edited when nobody had touched it.
  void _scheduleSave() {
    final collection = state.value;
    if (collection == null) return;
    // Dialogues follow their words in the same save (get-words-from-
    // subtitles-improvment AC-11, AC-26); links only shrink.
    if (collection.dialogues.isNotEmpty) collection.dialogues = afterEdit(collection);
    final now = DateTime.now();
    collection.updatedAt = now;
    collection.lastLocalModifiedAt = now;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), flush);
  }
}
