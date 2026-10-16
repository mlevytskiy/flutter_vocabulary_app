import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_folder.dart';
import '../models/collection_name.dart';
import '../models/word_collection.dart';
import '../models/story_run.dart';
import '../models/word_result.dart';
import 'collection_level.dart';
import 'filing.dart'
    show canMoveFolderInto, isInBin, ordersOf, placeInLevel;
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

  // ---- Filing actions and streams (T8) ----
  //
  // Each action is one write transaction, not debounced (QG-4), and answers
  // with a [FilingResult] instead of throwing (ADR-0003, sad §6 F1, F2, F5,
  // F6, F11). A level is a folder's (or the top level's) collections and
  // folders that are not themselves in the bin, numbered 0..n-1 together.

  Future<WordCollection?> _collectionById(String id) =>
      _isar.wordCollections.filter().collectionIdEqualTo(id).findFirst();

  Future<CollectionFolder?> _folderById(String id) =>
      _isar.collectionFolders.filter().folderIdEqualTo(id).findFirst();

  /// Runs [action] in one write transaction; a throw becomes `failed` and
  /// rolls the transaction back.
  Future<FilingResult> _filingTxn(Future<FilingResult> Function() action) async {
    try {
      return await _isar.writeTxn(action);
    } catch (_) {
      return FilingResult.failed;
    }
  }

  /// True for the top level and for a stored folder outside the bin,
  /// directly or through an ancestor.
  Future<bool> _folderUsable(String? folderId) async {
    if (folderId == null) return true;
    final folders = await _isar.collectionFolders.where().findAll();
    final folder = folders.where((f) => f.folderId == folderId).firstOrNull;
    if (folder == null) return false;
    return !isInBin(
      binned: folder.binnedAt != null,
      folderId: folder.parentId,
      parentOf: {for (final f in folders) f.folderId: f.parentId},
      binnedFolderIds: {
        for (final f in folders)
          if (f.binnedAt != null) f.folderId,
      },
    );
  }

  /// One level by order. Records without an order yet (the Isar null long,
  /// before the T6 backfill) sort first; ties go folders first, then by id.
  Future<List<LevelItem>> _readLevel(String? folderId) async {
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
    return [
      for (final f in folders) LevelItem.folder(f),
      for (final c in collections) LevelItem.collection(c),
    ]..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.id.compareTo(b.id);
      });
  }

  /// Places [id] in [folderId]'s level [at] (the end when null) and writes
  /// every order that changed. Inside a write transaction.
  Future<void> _placeInLevel(String? folderId, String id, {int? at}) async {
    final items = await _readLevel(folderId);
    final byId = {for (final i in items) i.id: i};
    final orders =
        ordersOf(placeInLevel([for (final i in items) i.id], id, at: at));
    for (final MapEntry(:key, value: order) in orders.entries) {
      final item = byId[key];
      if (item == null || item.order == order) continue;
      if (item.folder case final f?) {
        await _isar.collectionFolders.put(f..order = order);
      } else {
        await _isar.wordCollections.put(item.collection!..order = order);
      }
    }
  }

  /// Renumbers [folderId]'s level 0..n-1 in its current order.
  Future<void> _closeLevel(String? folderId) async {
    final items = await _readLevel(folderId);
    if (items.isEmpty) return;
    await _placeInLevel(folderId, items.last.id);
  }

  /// Renames a collection or a folder (AC-01, AC-17). Writes only the name,
  /// and raises `keep` for a collection (AC-19); `lastLocalModifiedAt`
  /// stays, so History order does not move.
  Future<FilingResult> rename(String id, String name) async {
    if (collectionNameProblem(name) != null) return FilingResult.invalidName;
    return _filingTxn(() async {
      final collection = await _collectionById(id);
      if (collection != null) {
        await _isar.wordCollections.put(collection
          ..name = name
          ..keep = true);
        return FilingResult.done;
      }
      final folder = await _folderById(id);
      if (folder == null) return FilingResult.notFound;
      await _isar.collectionFolders.put(folder..name = name);
      return FilingResult.done;
    });
  }

  /// Makes a folder named [name] at the end of [parentId]'s level (AC-13),
  /// null being the top level. `folder` is the stored folder when `result`
  /// is `done`, else null.
  Future<({FilingResult result, CollectionFolder? folder})> createFolder({
    String? parentId,
    required String name,
  }) async {
    if (collectionNameProblem(name) != null) {
      return (result: FilingResult.invalidName, folder: null);
    }
    final folder = CollectionFolder()
      ..folderId = uuidV4()
      ..name = name
      ..parentId = parentId;
    final result = await _filingTxn(() async {
      if (!await _folderUsable(parentId)) return FilingResult.notFound;
      final level = await _readLevel(parentId);
      folder.order = level.isEmpty ? 0 : level.last.order + 1;
      folder.id = await _isar.collectionFolders.put(folder);
      await _placeInLevel(parentId, folder.folderId);
      return FilingResult.done;
    });
    if (result != FilingResult.done) return (result: result, folder: null);
    return (result: result, folder: await _folderById(folder.folderId));
  }

  /// Moves a collection or a folder (with all inside it) into
  /// [targetFolderId], null being the top level, [at] that place in its
  /// order (the end when null), and renumbers the level it left (AC-14).
  /// Refuses a folder into itself or a folder inside it (AC-15), and an
  /// item or target that is missing or in the bin. Raises `keep` for a
  /// collection.
  Future<FilingResult> move(String id, String? targetFolderId, {int? at}) =>
      _filingTxn(() async {
        final collection = await _collectionById(id);
        final folder = collection == null ? await _folderById(id) : null;
        if (collection == null && folder == null) return FilingResult.notFound;
        if ((collection?.binnedAt ?? folder?.binnedAt) != null) {
          return FilingResult.notFound;
        }
        if (!await _folderUsable(targetFolderId)) return FilingResult.notFound;
        final String? from;
        if (folder != null) {
          final folders = await _isar.collectionFolders.where().findAll();
          final parentOf = {for (final f in folders) f.folderId: f.parentId};
          if (!canMoveFolderInto(folder.folderId, targetFolderId, parentOf)) {
            return FilingResult.intoItself;
          }
          from = folder.parentId;
          await _isar.collectionFolders.put(folder..parentId = targetFolderId);
        } else {
          from = collection!.folderId;
          await _isar.wordCollections.put(collection
            ..folderId = targetFolderId
            ..keep = true);
        }
        if (from != targetFolderId) await _closeLevel(from);
        await _placeInLevel(targetFolderId, id, at: at);
        return FilingResult.done;
      });

  /// Moves a collection or a folder to [newIndex] within its own level,
  /// where folders and collections share one order (AC-14). Raises `keep`
  /// for a collection.
  Future<FilingResult> reorder(String id, int newIndex) =>
      _filingTxn(() async {
        final collection = await _collectionById(id);
        final folder = collection == null ? await _folderById(id) : null;
        if (collection == null && folder == null) return FilingResult.notFound;
        if ((collection?.binnedAt ?? folder?.binnedAt) != null) {
          return FilingResult.notFound;
        }
        if (collection != null) {
          await _isar.wordCollections.put(collection..keep = true);
        }
        await _placeInLevel(
            collection != null ? collection.folderId : folder!.parentId, id,
            at: newIndex);
        return FilingResult.done;
      });

  /// Emits [read] once on listen and again after every write to collections
  /// or folders, in order. A failed read is skipped, never an error event.
  Stream<T> _watchFiling<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var pending = Future<void>.value();
    void emit() {
      pending = pending.then((_) async {
        try {
          final value = await read();
          if (!controller.isClosed) controller.add(value);
        } catch (_) {
          // ignored on purpose, see the class doc
        }
      });
    }

    controller = StreamController<T>(
      onListen: () {
        subscriptions
          ..add(_isar.wordCollections.watchLazy().listen((_) => emit()))
          ..add(_isar.collectionFolders.watchLazy().listen((_) => emit()));
        emit();
      },
      onCancel: () async {
        for (final s in subscriptions) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// One level of Collections (F2, F6): [folderId]'s folders and
  /// collections that are not in the bin, by order. Null is the top level.
  Stream<List<LevelItem>> watchLevel(String? folderId) =>
      _watchFiling(() => _readLevel(folderId));

  /// Every folder, binned ones too, for the path and the tree; unsorted.
  Stream<List<CollectionFolder>> watchFolders() =>
      _isar.collectionFolders.where().watch(fireImmediately: true);

  /// History (F11, AC-28): collections with at least one non-blank word
  /// that are not in the bin, directly or through a folder above them,
  /// newest `lastLocalModifiedAt` first. Emits on listen and after every
  /// write to collections or folders.
  Stream<List<WordCollection>> watchHistory() => _watchFiling(() async {
        final folders = await _isar.collectionFolders.where().findAll();
        final parentOf = {for (final f in folders) f.folderId: f.parentId};
        final binnedFolderIds = {
          for (final f in folders)
            if (f.binnedAt != null) f.folderId,
        };
        final all = await _isar.wordCollections
            .where()
            .sortByLastLocalModifiedAtDesc()
            .findAll();
        return [
          for (final s in all)
            if (!s.isEmpty &&
                !isInBin(
                  binned: s.binnedAt != null,
                  folderId: s.folderId,
                  parentOf: parentOf,
                  binnedFolderIds: binnedFolderIds,
                ))
              await _withRowIds(s),
        ];
      });

  // ---- end of filing actions and streams (T8) ----

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
