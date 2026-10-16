import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_collection.dart';
import '../models/story_run.dart';
import '../models/word_result.dart';
import 'source_photo_store.dart' show uuidV4;

/// Persists sessions in an Isar database (`vocab`), plus the one
/// `shared_preferences` pointer saying which session is the current one — the
/// pointer lives here because it is the same concept, "which session is now".
///
/// Nothing in this class throws on bad data: a store that kills the app on
/// launch because of a bad write is worse than one that loses a session.
class CollectionStore {
  static const _currentCollectionKey = 'current_session_id';
  static const _switchedCollectionKey = 'switched_session_id';
  static const _switchedAtKey = 'switched_at';
  static const _seenCollectionKey = 'seen_session_id';
  static const _seenAtKey = 'seen_at';

  final Isar _isar;
  final SharedPreferences _prefs;

  CollectionStore._(this._isar, this._prefs);

  static Future<CollectionStore> open({String? directory}) async {
    final dir =
        directory ?? (await getApplicationDocumentsDirectory()).path;
    final isar = Isar.getInstance('vocab') ??
        await Isar.open([WordCollectionSchema, StoryRunSchema],
            directory: dir, name: 'vocab');
    final prefs = await SharedPreferences.getInstance();
    final store = CollectionStore._(isar, prefs);
    await store._fillRowIdsEverywhere();
    return store;
  }

  /// Gives every row without a [WordPair.rowId] one and saves it, so rows
  /// stored before mnemonic-story get stable ids once. Returns [s] itself.
  /// Never throws, see the class doc.
  Future<WordCollection> _withRowIds(WordCollection s) async {
    if (s.words.every((w) => w.rowId.isNotEmpty)) return s;
    for (final w in s.words) {
      if (w.rowId.isEmpty) w.rowId = uuidV4();
    }
    try {
      await _isar.writeTxn(() => _isar.wordCollections.put(s));
    } catch (_) {
      // the ids stay on this object; the next read tries again
    }
    return s;
  }

  Future<void> _fillRowIdsEverywhere() async {
    try {
      for (final s in await _isar.wordCollections.where().findAll()) {
        await _withRowIds(s);
      }
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  Future<void> close() => _isar.close();

  Future<WordCollection?> byId(String collectionId) async {
    try {
      final s = await _isar.wordCollections
          .filter()
          .collectionIdEqualTo(collectionId)
          .findFirst();
      return s == null ? null : await _withRowIds(s);
    } catch (_) {
      return null;
    }
  }

  /// The session with the newest [WordCollection.lastLocalModifiedAt], or null on an
  /// empty store.
  Future<WordCollection?> newest() async {
    try {
      final s = await _isar.wordCollections
          .where()
          .sortByLastLocalModifiedAtDesc()
          .findFirst();
      return s == null ? null : await _withRowIds(s);
    } catch (_) {
      return null;
    }
  }

  /// Sessions with at least one non-blank word, newest first.
  Future<List<WordCollection>> nonEmpty() async {
    try {
      final all = await _isar.wordCollections
          .where()
          .sortByLastLocalModifiedAtDesc()
          .findAll();
      return [
        for (final s in all)
          if (!s.isEmpty) await _withRowIds(s),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Upsert on [WordCollection.collectionId]. Blank pairs — the trailing empty row the
  /// screen always keeps — are stripped before the write and the caller's own
  /// session object is left untouched.
  Future<void> put(WordCollection s) async {
    try {
      // A row keeps its id for good, so a new one gets it now, on the
      // caller's object too: a group may name it before the next read.
      for (final w in s.words) {
        if (!w.isEmpty && w.rowId.isEmpty) w.rowId = uuidV4();
      }
      await _isar.writeTxn(() async {
        final existing = await _isar.wordCollections
            .filter()
            .collectionIdEqualTo(s.collectionId)
            .findFirst();
        final toWrite = WordCollection()
          ..id = existing?.id ?? Isar.autoIncrement
          ..collectionId = s.collectionId
          ..updatedAt = s.updatedAt
          ..lastLocalModifiedAt = s.lastLocalModifiedAt
          ..isShared = s.isShared
          ..words = [
            for (final w in s.words)
              if (!w.isEmpty) w.copy(),
          ]
          ..sources = [for (final p in s.sources) p.copy()]
          ..publishedId = s.publishedId
          ..editToken = s.editToken
          ..groups = [for (final g in s.groups) g.copy()]
          ..selectedGroupId = s.selectedGroupId
          ..groupedWordsKey = s.groupedWordsKey
          ..dialogues = [for (final d in s.dialogues) d.copy()]
          ..tags = [...s.tags]
          // Results are written only by [appendResult]: a caller holding an
          // older copy of the session must not wipe them (learn-kit S-22).
          ..results = existing?.results ?? [for (final r in s.results) r.copy()];
        s.id = await _isar.wordCollections.put(toWrite);
      });
    } catch (_) {
      // Losing one debounced write is survivable; crashing the app is not.
    }
  }

  /// Appends a Step 3 word result to the stored session (learn-kit S-22,
  /// S-23), dropping the oldest past [WordCollection.maxResults]. Neither
  /// `updatedAt` nor `lastLocalModifiedAt` moves, so History order stays
  /// (AC-37). False when there is no such session or the write failed.
  Future<bool> appendResult(String collectionId, WordResult result) async {
    try {
      return await _isar.writeTxn(() async {
        final existing = await _isar.wordCollections
            .filter()
            .collectionIdEqualTo(collectionId)
            .findFirst();
        if (existing == null) return false;
        final results = [...existing.results, result.copy()];
        if (results.length > WordCollection.maxResults) {
          results.removeRange(0, results.length - WordCollection.maxResults);
        }
        existing.results = results;
        await _isar.wordCollections.put(existing);
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> delete(String collectionId) async {
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.wordCollections
            .filter()
            .collectionIdEqualTo(collectionId)
            .findFirst();
        if (existing != null) await _isar.wordCollections.delete(existing.id);
      });
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  /// Emits once immediately and again after every write. The drawer rule and
  /// the History screen (task-10) read this.
  Stream<List<WordCollection>> watchNonEmpty() => _isar.wordCollections
      .where()
      .sortByLastLocalModifiedAtDesc()
      .watch(fireImmediately: true)
      .asyncMap((all) async => [
            for (final s in all)
              if (!s.isEmpty) await _withRowIds(s),
          ]);

  Future<String?> currentCollectionId() async =>
      _prefs.getString(_currentCollectionKey);

  Future<void> setCurrentCollectionId(String collectionId) async {
    await _prefs.setString(_currentCollectionKey, collectionId);
  }

  /// Records that the learner picked [collectionId] from History at [at]
  /// (edit-session-from-history, ADR-0002). Kept beside the current-session
  /// pointer rather than on the session so a pick never looks like an edit.
  /// Nothing clears it; [switchedAt] only answers for the id it names.
  Future<void> setSwitched(String collectionId, DateTime at) async {
    try {
      await _prefs.setString(_switchedCollectionKey, collectionId);
      await _prefs.setString(_switchedAtKey, at.toIso8601String());
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  /// When [collectionId] was last picked from History, or null if the pick
  /// record names another session, is missing, or cannot be read.
  Future<DateTime?> switchedAt(String collectionId) async {
    try {
      if (_prefs.getString(_switchedCollectionKey) != collectionId) return null;
      final at = _prefs.getString(_switchedAtKey);
      return at == null ? null : DateTime.tryParse(at);
    } catch (_) {
      return null;
    }
  }

  /// Records that [collectionId], with words, was on screen with the app open
  /// at [at] (owner, 2026-10-16). Kept beside the pointer like a pick, so
  /// being looked at never looks like an edit; [seenAt] only answers for the
  /// id it names.
  Future<void> setSeen(String collectionId, DateTime at) async {
    try {
      await _prefs.setString(_seenCollectionKey, collectionId);
      await _prefs.setString(_seenAtKey, at.toIso8601String());
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  /// When [collectionId] was last seen open, or null if the record names
  /// another session, is missing, or cannot be read.
  Future<DateTime?> seenAt(String collectionId) async {
    try {
      if (_prefs.getString(_seenCollectionKey) != collectionId) return null;
      final at = _prefs.getString(_seenAtKey);
      return at == null ? null : DateTime.tryParse(at);
    } catch (_) {
      return null;
    }
  }
}
