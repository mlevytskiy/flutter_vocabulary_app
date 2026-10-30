import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/dialogues/dialogue_rules.dart';
import '../../core/models/film_dialogue.dart';
import '../../core/models/name_kind.dart';
import '../../core/models/tag_kind.dart';
import '../../core/models/word_collection.dart';
import '../../core/models/session_source.dart';
import '../../core/models/translation_result.dart';
import '../../core/models/word_pair.dart';
import '../../core/models/word_origin.dart';
import '../../core/providers.dart';
import '../../core/services/collection_store.dart';
import '../../core/services/filing.dart';
import '../../core/services/source_photo_store.dart' show uuidV4;
import '../../core/words/context_backfill.dart';
import '../../core/words/word_origin_rules.dart';

part 'words_notifier.g.dart';

/// Owns the current [WordCollection]. `WordsScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.
@Riverpod(keepAlive: true)
class WordsNotifier extends _$WordsNotifier {
  // Riverpod 2's rule: every new state notifies (toolchain-upgrade).
  @override
  bool updateShouldNotify(AsyncValue<WordCollection> previous, AsyncValue<WordCollection> next) =>
      asyncNotifyAsBefore(previous, next);

  Timer? _saveTimer;

  /// True between a mutation and the write that persists it. `flush()` is
  /// called on every `AppLifecycleState.paused`, so without this a plain
  /// background-or-force-quit would write — and, worse, re-stamp — a session
  /// nobody edited.
  bool _dirty = false;

  /// The collection whose name the AI is being asked for, and when the last
  /// ask failed (collection-naming): one ask at a time, and none for
  /// [_namingRetryAfter] after a failure.
  String? _namingFor;
  DateTime? _namingFailedAt;
  static const _namingRetryAfter = Duration(seconds: 30);

  /// The same for the AI's description (owner, 2026-10-18).
  String? _describingFor;
  DateTime? _describingFailedAt;

  /// True while the launch upgrade asks for every pending name and
  /// description in one request; the single asks wait for it.
  bool _autofillRunning = false;

  @override
  Future<WordCollection> build() async {
    ref.onDispose(() => _saveTimer?.cancel());
    // A collection opened with enough words but no name yet is named now.
    listenSelf((previous, next) {
      if (previous?.value?.collectionId !=
          next.value?.collectionId) {
        _maybeAutoName();
        _maybeAutoDescribe();
      }
    });
    final store = await ref.read(collectionStoreProvider.future);
    await store.sweepBin(DateTime.now());
    _autofillRunning = true;
    unawaited(_autofillPending(store));
    return _openCurrent(store);
  }

  /// The upgrade from before collection-naming (owner, 2026-10-18): every
  /// collection that should have an AI name (5 words) or description (20
  /// words) and has none gets it from one request at launch. What does not
  /// come back stays as it is; the next launch, or a word added to the
  /// current collection, asks again.
  Future<void> _autofillPending(CollectionStore store) async {
    try {
      final pending = await store.pendingAutofill();
      if (pending.isEmpty) return;
      debugPrint('VOCAB: autofill: asking for ${pending.length} collections');
      final answers = await ref.read(collectionNamingServiceProvider).autofill([
        for (final p in pending)
          (
            id: p.collection.collectionId,
            words: p.collection.words,
            name: p.name,
            description: p.description,
          ),
      ]);
      if (answers == null) return;
      await _applyAnswers(store, answers);
      debugPrint('VOCAB: autofill: ${answers.length} answered');
    } catch (e) {
      debugPrint('VOCAB: autofill failed: $e');
    } finally {
      _autofillRunning = false;
      // A disposed notifier has no state to update (Riverpod 3 throws).
      if (ref.mounted) {
        // The copy on screen may predate the answers: take the stored kinds
        // before deciding whether the current collection still needs asking.
        final current = state.isLoading ? null : state.value;
        if (current != null) {
          try {
            final stored = await store.byId(current.collectionId);
            if (stored != null && ref.mounted) {
              _adopt(stored, withSources: false);
            }
          } catch (_) {}
        }
        if (ref.mounted) {
          _maybeAutoName();
          _maybeAutoDescribe();
          // Then, in the background, the empty contexts (word-context AC-12,
          // ADR-0004); once per app start.
          unawaited(ref
              .read(contextBackfillProvider)
              .start(onWritten: _takeBackfilledContexts));
        }
      }
    }
  }

  /// The contexts the backfill just stored, put on the screen's copy of the
  /// same collection too, so its next save keeps them (word-context AC-12).
  void _takeBackfilledContexts(String collectionId, List<ContextFill> fills) {
    if (!ref.mounted || state.isLoading) return;
    final c = state.value;
    if (c == null || c.collectionId != collectionId) return;
    applyContextFills(c.words, fills);
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
    final current = state.value;
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
  Future<bool> switchTo(String collectionId) => open(collectionId);

  /// Opens collection [id] on the main screen with no question (AC-09,
  /// AC-18): the autosave is flushed, the left collection is erased at once
  /// when it is empty and untouched (AC-19), the pointer moves and the opened
  /// collection is shown. Opening the current one changes nothing. Returns
  /// false, touching nothing, when [id] is not in the store.
  Future<bool> open(String id) async {
    final store = await ref.read(collectionStoreProvider.future);
    if (state.value?.collectionId == id) return true;
    final picked = await store.byId(id);
    if (picked == null) return false;
    picked.words = picked.words.toList(); // growable, see build()
    picked.sources = picked.sources.toList();
    await _leaveAndShow(store, picked);
    return true;
  }

  /// New collection (AC-10): a kept, empty, date-named collection at the end
  /// of [folderId]'s level (null: the top level) becomes the current one.
  Future<void> newCollection(String? folderId) =>
      newCollectionWithDetails(folderId);

  /// New collection with the details typed in the Collection details sheet
  /// (collection-tags AC-01): as [newCollection], but named, described and
  /// tagged. A name the store refuses becomes the date name.
  Future<void> newCollectionWithDetails(
    String? folderId, {
    String? name,
    String? description,
    List<String> origin = const [],
    List<String> topic = const [],
  }) async {
    final store = await ref.read(collectionStoreProvider.future);
    final made = await store.create(
      folderId: folderId,
      keep: true,
      name: name,
      description: description,
      origin: origin,
      topic: topic,
    );
    made.words = [WordPair()];
    await _leaveAndShow(store, made);
  }

  Future<void> _leaveAndShow(
      CollectionStore store, WordCollection next) async {
    await flush();
    final current = state.value;
    if (current != null && current.collectionId != next.collectionId) {
      final stored = await store.byId(current.collectionId);
      if (stored != null &&
          isEmptyAndUntouched(
            hasWords: !stored.isEmpty,
            hasSources: stored.sources.isNotEmpty,
            hasNotesOrTags: stored.tags.isNotEmpty ||
                (stored.description ?? '').isNotEmpty ||
                stored.originTags.isNotEmpty ||
                stored.topicTags.isNotEmpty ||
                stored.sources.any((s) =>
                    (s.title ?? '').isNotEmpty ||
                    (s.description ?? '').isNotEmpty ||
                    s.links.isNotEmpty ||
                    s.tags.isNotEmpty),
            keep: stored.keep,
          )) {
        await store.delete(current.collectionId);
      }
    }

    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    await store.setCurrentCollectionId(next.collectionId);
    state = AsyncData(next);
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
  ///
  /// word-context AC-04/AC-05: the screen says what the learner did, because
  /// only it can tell a typed or picked value from one the app filled.
  /// [translationEditedByLearner] / [definitionEditedByLearner] mark a real
  /// change the learner made (typing, or a pick from the ⋯ list) and set the
  /// origin's edit flag; a lightning fill or an import leaves them false.
  /// [wordChanged] marks a real change of the English word, by anyone: the
  /// row's context, its kind, both edit flags and `contextTried` go.
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
    WordOrigin? origin,
    String? context,
    ContextKind? contextKind,
    bool wordChanged = false,
    bool translationEditedByLearner = false,
    bool definitionEditedByLearner = false,
  }) {
    if (!state.hasValue) return;
    final collection = state.value!;
    if (i < 0 || i >= collection.words.length) return;
    final current = collection.words[i];
    var next = WordPair(
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
      // So do its origin and context (word-context AC-14).
      // A row filled from an import takes the import's (word-context AC-06).
      context: context ?? current.context,
      contextKind: contextKind ?? current.contextKind,
      contextTried: current.contextTried,
    )..origin = (origin ?? current.origin).copy();
    if (translationOptions != null) {
      next.translationOptions = translationOptions;
    }
    if (wordChanged) next = withChangedWord(next);
    if (translationEditedByLearner) next = withEditedTranslation(next);
    if (definitionEditedByLearner) next = withEditedDefinition(next);
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
    final collection = state.value;
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
    _putSetSource(collection, setId, name, url);
    state = AsyncData(collection);
    _scheduleSave();
    return id;
  }

  static String _putSetSource(
      WordCollection collection, String setId, String name, String url) {
    final id = 'quizlet-$setId';
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
    final collection = state.value;
    if (collection == null) return 'subtitles-${uuidV4()}';
    final before = collection.sources.length;
    final urlBefore = _subtitlesSource(collection, title)?.url;
    final id = _putSubtitlesSource(collection, title, poster);
    if (collection.sources.length != before ||
        _subtitlesSource(collection, title)?.url != urlBefore) {
      state = AsyncData(collection);
      _scheduleSave();
    }
    return id;
  }

  static SessionSource? _subtitlesSource(WordCollection c, String title) => c
      .sources
      .where((s) => s.kind == SourceKind.subtitles && s.name == title)
      .firstOrNull;

  static String _putSubtitlesSource(
      WordCollection collection, String title, String? poster) {
    final existing = _subtitlesSource(collection, title);
    if (existing != null) {
      if (existing.url == null && poster != null) existing.url = poster;
      return existing.id;
    }
    final id = 'subtitles-${uuidV4()}';
    collection.sources.add(SessionSource()
      ..id = id
      ..takenAt = DateTime.now()
      ..kind = SourceKind.subtitles
      ..name = title
      ..url = poster);
    return id;
  }

  // ---- Late results (collections-screen ADR-0006, AC-11, AC-27) ----

  /// A lookup that started in [collectionId] and finished after another
  /// collection was opened: [change] is applied to the row with [rowId] in
  /// that collection, in one atomic store update, also while it is in the
  /// bin. A row the learner removed meanwhile is skipped. A row not stored
  /// yet when the lookup started has no id: it is found by its [word] and
  /// [translation] as they were then. False when the
  /// collection was erased for good (the result is dropped and logged by the
  /// store); the open collection is never touched.
  Future<bool> updateRowIn(
      String collectionId, String rowId, void Function(WordPair row) change,
      {String word = '', String translation = ''}) async {
    final store = await ref.read(collectionStoreProvider.future);
    return store.update(collectionId, (c) {
      final row = c.words
          .where((w) => rowId.isNotEmpty
              ? w.rowId == rowId
              : w.word == word && w.translation == translation)
          .firstOrNull;
      if (row != null) change(row);
    });
  }

  /// Rows from a photo reading, a Quizlet import or a subtitle import that
  /// started in [collectionId] and finished after another collection was
  /// opened (ADR-0006). They are shaped as the screen shapes them in the open
  /// collection: the [photo], [set] or [film] source joins that collection's
  /// sources first and the rows point at it, they go after its last word,
  /// each with a row id, and the subtitle [dialogues] follow the rows. False
  /// when the collection was erased for good.
  Future<bool> addWordsTo(
    String collectionId,
    List<WordPair> pairs, {
    SessionSource? photo,
    ({String id, String name, String url})? set,
    String? film,
    String? poster,
    List<ImportedDialogue> dialogues = const [],
  }) async {
    final store = await ref.read(collectionStoreProvider.future);
    return store.update(collectionId, (c) {
      String? sourceId;
      if (photo != null) {
        c.sources = [...c.sources, photo];
        sourceId = photo.id;
      } else if (set != null) {
        c.sources = c.sources.toList();
        sourceId = _putSetSource(c, set.id, set.name, set.url);
      } else if (film != null) {
        c.sources = c.sources.toList();
        sourceId = _putSubtitlesSource(c, film, poster);
      }
      for (final p in pairs) {
        if (sourceId != null) p.sourceId = sourceId;
        if (p.rowId.isEmpty) p.rowId = uuidV4();
      }
      final words = c.words.toList();
      while (words.isNotEmpty && words.last.isEmpty) {
        words.removeLast();
      }
      c.words = [...words, ...pairs];
      if (dialogues.isNotEmpty) {
        final kept = atDone(dialogues, pairs);
        if (kept.isNotEmpty) {
          if (c.publishedId != null && c.editToken != null) {
            final importId = uuidV4();
            for (final d in kept) {
              d
                ..importId = importId
                ..importRowIds = [for (final w in pairs) w.rowId]
                ..pushState = PushState.pending;
            }
          }
          c.dialogues = [...c.dialogues, ...kept];
        }
      }
    });
  }

  /// Changes the note of the source [id] (notes-editing, owner 2026-10-15;
  /// collection-tags ADR-0004): written through the store in one transaction,
  /// then the stored record's sources and details are adopted, so a later
  /// autosave cannot write an older copy back. Every argument left out keeps
  /// its value; an empty title or description is dropped. Returns the kinds
  /// whose tag the cap kept off the collection (AC-29).
  Future<Set<TagKind>> updateSourceNote(
    String id, {
    String? title,
    String? description,
    List<String>? links,
    List<String>? origin,
    List<String>? topic,
  }) async {
    final collection = state.value;
    if (collection == null || !collection.sources.any((s) => s.id == id)) {
      return const {};
    }
    await flush();
    final store = await ref.read(collectionStoreProvider.future);
    final refused = await store.saveSourceNote(
      collection.collectionId,
      id,
      title: title,
      description: description,
      links: links,
      origin: origin,
      topic: topic,
    );
    final stored = await store.byId(collection.collectionId);
    if (stored != null) _adopt(stored, withSources: true);
    return refused;
  }

  /// Saves the collection details through the store (collection-tags Flow 1)
  /// and adopts the stored values at once, without the debounce. Null keeps a
  /// field. False when the store refused (a bad name) or the collection is
  /// gone.
  Future<bool> saveDetails({
    String? name,
    String? description,
    List<String>? origin,
    List<String>? topic,
  }) async {
    final collection = state.value;
    if (collection == null) return false;
    await flush();
    final store = await ref.read(collectionStoreProvider.future);
    final stored = await store.setDetails(
      collection.collectionId,
      name: name,
      description: description,
      origin: origin,
      topic: topic,
    );
    if (stored == null) return false;
    _adopt(stored, withSources: false);
    return true;
  }

  /// Sets the collection's tags of [kind] (the Notes page editor).
  Future<bool> setCollectionTags(TagKind kind, List<String> tags) =>
      saveDetails(
        origin: kind == TagKind.origin ? tags : null,
        topic: kind == TagKind.topic ? tags : null,
      );

  /// Takes the values only the store writes from the [stored] record into the
  /// current one: details, tags, both times (never earlier than the ones held)
  /// and, after a source note, the sources, which `put()` copies from the
  /// caller.
  ///
  /// Never while loading: a rebuild keeps the previous collection as the
  /// loading value, and adopting into it would put it back on screen.
  void _adopt(WordCollection stored, {required bool withSources}) {
    // Called after awaits; a disposed notifier has no state (Riverpod 3 throws).
    if (!ref.mounted) return;
    if (state.isLoading) return;
    final c = state.value;
    if (c == null || c.collectionId != stored.collectionId) return;
    c
      ..name = stored.name
      ..nameKind = stored.nameKind
      ..keep = stored.keep || c.keep
      ..description = stored.description
      ..descriptionKind = stored.descriptionKind
      ..originTags = [...stored.originTags]
      ..topicTags = [...stored.topicTags]
      ..updatedAt = stored.updatedAt.isAfter(c.updatedAt)
          ? stored.updatedAt
          : c.updatedAt
      ..lastLocalModifiedAt =
          stored.lastLocalModifiedAt.isAfter(c.lastLocalModifiedAt)
              ? stored.lastLocalModifiedAt
              : c.lastLocalModifiedAt;
    if (withSources) c.sources = stored.sources.toList();
    state = AsyncData(c);
  }

  /// Puts [pair] at [index] of the words (the Notes words dialog adds a word
  /// right after its source's rows). The main screen does not see this until
  /// it takes [takeEditedElsewhere].
  void insertAt(int index, WordPair pair) {
    final collection = state.value;
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
    final collection = state.value;
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
    final collection = state.value;
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
    final collection = state.value;
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
    // Taken before the await: Riverpod 3 refuses `state` once the notifier is
    // disposed, and the last words must still be written (toolchain-upgrade).
    final collection = state.value!;
    final store = await ref.read(collectionStoreProvider.future);
    await store.put(collection);
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
    _maybeAutoName();
    _maybeAutoDescribe();
  }

  /// A collection whose description nobody wrote, still empty, that reached
  /// [minWordsForAutoDescription] words gets the AI's description (owner,
  /// 2026-10-18). The store takes it only while still undefined, so a
  /// description typed meanwhile wins.
  void _maybeAutoDescribe() {
    final c = state.value;
    if (c == null ||
        c.descriptionKind != NameKind.undefined ||
        (c.description ?? '').isNotEmpty) {
      return;
    }
    if (CollectionStore.wordCount(c) < minWordsForAutoDescription) return;
    if (_describingFor != null || _autofillRunning) return;
    final failed = _describingFailedAt;
    if (failed != null &&
        DateTime.now().difference(failed) < _namingRetryAfter) {
      return;
    }
    unawaited(_autoDescribe(c.collectionId, [...c.words]));
  }

  Future<void> _autoDescribe(String collectionId, List<WordPair> words) async {
    _describingFor = collectionId;
    try {
      final text =
          await ref.read(collectionNamingServiceProvider).descriptionFor(words);
      if (text == null) {
        _describingFailedAt = DateTime.now();
        return;
      }
      _describingFailedAt = null;
      final store = await ref.read(collectionStoreProvider.future);
      final stored = await store.setAutoDescription(collectionId, text);
      if (stored != null) _adopt(stored, withSources: false);
    } finally {
      _describingFor = null;
    }
  }

  /// Stores the AI's [answers] by collection id; the current collection on
  /// screen takes them at once. Returns how many names went in.
  Future<int> _applyAnswers(CollectionStore store,
      Map<String, ({String? name, String? description})> answers) async {
    var named = 0;
    for (final MapEntry(key: id, value: answer) in answers.entries) {
      WordCollection? stored;
      if (answer.name != null) {
        final n = await store.setAutoName(id, answer.name!);
        if (n != null) named++;
        stored = n ?? stored;
      }
      if (answer.description != null) {
        stored =
            await store.setAutoDescription(id, answer.description!) ?? stored;
      }
      if (stored != null) _adopt(stored, withSources: false);
    }
    return named;
  }

  /// "Replace all date names" (Collections settings, owner 2026-10-18): the
  /// small date-named collections become "Vocabulary N" at once, the rest get
  /// AI names (and descriptions from 20 words) from one request. `ai` counts
  /// the names that came back, `kept` the date names left because the AI
  /// gave none (a failed request, or no answer for them).
  Future<({int vocabulary, int ai, int kept})> replaceDateNames() async {
    final store = await ref.read(collectionStoreProvider.future);
    await flush();
    final replaced = await store.replaceDateNames();
    var ai = 0;
    if (replaced.forAi.isNotEmpty) {
      final answers = await ref.read(collectionNamingServiceProvider).autofill([
        for (final p in replaced.forAi)
          (
            id: p.collection.collectionId,
            words: p.collection.words,
            name: true,
            description: p.description,
          ),
      ]);
      if (answers != null) ai = await _applyAnswers(store, answers);
    }
    final current = state.value;
    if (current != null) {
      final stored = await store.byId(current.collectionId);
      if (stored != null) _adopt(stored, withSources: false);
    }
    return (
      vocabulary: replaced.vocabulary,
      ai: ai,
      kept: replaced.forAi.length - ai,
    );
  }

  /// collection-naming (owner, 2026-10-18): a collection nobody named that
  /// reached [minWordsForAutoName] words gets the AI's name. The store takes
  /// it only while the name is still undefined, so a name typed meanwhile
  /// wins; the main screen's title animates to it.
  void _maybeAutoName() {
    final c = state.value;
    if (c == null || c.nameKind != NameKind.undefined) return;
    if (CollectionStore.wordCount(c) < minWordsForAutoName) return;
    if (_namingFor != null || _autofillRunning) return;
    final failed = _namingFailedAt;
    if (failed != null &&
        DateTime.now().difference(failed) < _namingRetryAfter) {
      return;
    }
    unawaited(_autoName(c.collectionId, [...c.words]));
  }

  Future<void> _autoName(String collectionId, List<WordPair> words) async {
    _namingFor = collectionId;
    try {
      final name =
          await ref.read(collectionNamingServiceProvider).nameFor(words);
      if (name == null) {
        _namingFailedAt = DateTime.now();
        return;
      }
      _namingFailedAt = null;
      final store = await ref.read(collectionStoreProvider.future);
      final stored = await store.setAutoName(collectionId, name);
      if (stored != null) _adopt(stored, withSources: false);
    } finally {
      _namingFor = null;
    }
  }
}
