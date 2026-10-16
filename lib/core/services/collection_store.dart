import 'package:flutter/foundation.dart' show debugPrint;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_folder.dart';
import '../models/collection_name.dart';
import '../models/word_collection.dart';
import '../models/story_run.dart';
import '../models/word_result.dart';
import 'filing.dart' show ordersOf, placeInLevel;
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
        await Isar.open(
            [WordCollectionSchema, StoryRunSchema, CollectionFolderSchema],
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

  /// Inserts a new collection named after this moment
  /// (`defaultCollectionName`), at the end of its level: [folderId], null
  /// being the top level. The only way a collection comes into being
  /// (ADR-0003): first launch and the launch rule pass `keep: false`, New
  /// collection `keep: true` (AC-19). Returns the new collection, with no
  /// words; on a failed write it is returned unsaved, see the class doc.
  Future<WordCollection> create({String? folderId, bool keep = false}) async {
    final collection = WordCollection.create();
    collection
      ..name = defaultCollectionName(collection.updatedAt)
      ..folderId = folderId
      ..keep = keep;
    try {
      await _isar.writeTxn(() async {
        collection.id = await _isar.wordCollections.put(collection);
        await _renumberLevel(folderId, newCollection: collection);
      });
    } catch (_) {
      // Losing the write is survivable; crashing the app is not.
    }
    return collection;
  }

  /// Numbers one level 0..n-1 in its current order with [newCollection]
  /// placed at the end (data-model.md). The level is its collections and
  /// folders that are not in the bin. Runs inside a write transaction.
  Future<void> _renumberLevel(String? folderId,
      {required WordCollection newCollection}) async {
    final collections = await (folderId == null
            ? _isar.wordCollections.where().folderIdIsNull()
            : _isar.wordCollections.where().folderIdEqualTo(folderId))
        .filter()
        .binnedAtIsNull()
        .findAll();
    final folders = await (folderId == null
            ? _isar.collectionFolders.filter().parentIdIsNull()
            : _isar.collectionFolders.filter().parentIdEqualTo(folderId))
        .binnedAtIsNull()
        .findAll();
    final byKey = <String, ({int order, Future<void> Function(int) write})>{
      for (final c in collections)
        if (c.id != newCollection.id)
          'c:${c.collectionId}': (
            order: c.order,
            write: (o) async => _isar.wordCollections.put(c..order = o),
          ),
      for (final f in folders)
        'f:${f.folderId}': (
          order: f.order,
          write: (o) async => _isar.collectionFolders.put(f..order = o),
        ),
    };
    final level = byKey.keys.toList()
      ..sort((a, b) => byKey[a]!.order.compareTo(byKey[b]!.order));
    final newKey = 'c:${newCollection.collectionId}';
    final orders = ordersOf(placeInLevel(level, newKey));
    for (final MapEntry(:key, value: order) in orders.entries) {
      if (key == newKey) {
        await _isar.wordCollections.put(newCollection..order = order);
      } else if (byKey[key]!.order != order) {
        await byKey[key]!.write(order);
      }
    }
  }

  // ---- Atomic update for background writers (T7) ----

  /// Reads the stored collection [collectionId], applies [change] to it and
  /// writes it back, all in one write transaction, so no other writer can
  /// slip in between (ADR-0006, sad §6 F10). Background writers — story runs,
  /// word grouping, dialogue delivery, exam results — use this instead of a
  /// whole-copy [put], changing only their own fields.
  ///
  /// [change] may not touch filing: name, folderId, order, binnedAt,
  /// binnedFromFolderId and keep are restored from the stored record after
  /// it runs. Neither edit time moves unless [change] moves it. With no
  /// stored record (erased) nothing runs or is written and the result is
  /// false (AC-27); false too when the write failed. Never throws.
  Future<bool> update(
      String collectionId, void Function(WordCollection) change) async {
    try {
      final written = await _isar.writeTxn(() async {
        final stored = await _isar.wordCollections
            .filter()
            .collectionIdEqualTo(collectionId)
            .findFirst();
        if (stored == null) return false;
        final id = stored.id,
            name = stored.name,
            folderId = stored.folderId,
            order = stored.order,
            binnedAt = stored.binnedAt,
            binnedFromFolderId = stored.binnedFromFolderId,
            keep = stored.keep;
        change(stored);
        stored
          ..id = id
          ..collectionId = collectionId
          ..name = name
          ..folderId = folderId
          ..order = order
          ..binnedAt = binnedAt
          ..binnedFromFolderId = binnedFromFolderId
          ..keep = keep;
        await _isar.wordCollections.put(stored);
        return true;
      });
      if (!written) {
        debugPrint('VOCAB: update for $collectionId dropped, collection erased');
      }
      return written;
    } catch (_) {
      return false;
    }
  }

  /// Saves the caller's copy over the stored collection with the same
  /// [WordCollection.collectionId]. Blank pairs — the trailing empty row the
  /// screen always keeps — are stripped before the write and the caller's own
  /// collection object is left untouched.
  ///
  /// Never inserts: with no stored record of that id nothing is written, so
  /// an erased collection never comes back (ADR-0003). The filing fields
  /// (name, folderId, order, binnedAt, binnedFromFolderId, keep) come from
  /// the stored record, never from the caller; the one exception is that
  /// `keep` becomes true when the copy has a word, and it is never lowered.
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
        if (existing == null) return;
        final toWrite = WordCollection()
          ..id = existing.id
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
          ..results = existing.results
          ..name = existing.name
          ..folderId = existing.folderId
          ..order = existing.order
          ..binnedAt = existing.binnedAt
          ..binnedFromFolderId = existing.binnedFromFolderId
          ..keep = existing.keep || !s.isEmpty;
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
  Future<bool> appendResult(String collectionId, WordResult result) =>
      update(collectionId, (existing) {
        final results = [...existing.results, result.copy()];
        if (results.length > WordCollection.maxResults) {
          results.removeRange(0, results.length - WordCollection.maxResults);
        }
        existing.results = results;
      });

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
