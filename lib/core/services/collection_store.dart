import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_folder.dart';
import '../models/collection_name.dart';
import '../models/word_collection.dart';
import '../models/session_source.dart';
import '../models/story_run.dart';
import '../models/word_result.dart';
import 'collection_level.dart';
import 'filing.dart'
    show
        canMoveFolderInto,
        descendantsOf,
        isExpired,
        isInBin,
        ordersOf,
        placeInLevel,
        restoreTarget;
import 'source_photo_store.dart' show SourcePhotoStore, uuidV4;

/// Persists sessions in an Isar database (`vocab`), plus the one
/// `shared_preferences` pointer saying which session is the current one — the
/// pointer lives here because it is the same concept, "which session is now".
///
/// Nothing in this class throws on bad data: a store that kills the app on
/// launch because of a bad write is worse than one that loses a session.
class CollectionStore {
  static const _currentCollectionKey = 'current_session_id';
  /// Keys of the pick and seen records the old launch rule kept; removed once
  /// at startup, never written (collections-screen ADR-0007).
  static const _legacyKeys = [
    'switched_session_id',
    'switched_at',
    'seen_session_id',
    'seen_at',
  ];

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
    for (final k in _legacyKeys) {
      if (prefs.containsKey(k)) await prefs.remove(k);
    }
    await store._fillRowIdsEverywhere();
    await store._backfillFiling();
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

  // ---- One-time filing backfill (T6) ----

  /// Files every record from before collections-screen, the ones with no
  /// name (AC-04, data-model.md "One-time backfill"), in one transaction:
  /// named after its creation moment, at the top level, numbered oldest
  /// first after whatever the top level already holds (a store where some
  /// records are filed keeps their places), and kept when it has a word.
  /// Only the filing fields change (QG-2). A failed write is logged and
  /// runs again on the next open; nothing here throws.
  Future<void> _backfillFiling() async {
    try {
      final (fromId, fallback) = await _isar.writeTxn(() async {
        final unnamed =
            await _isar.wordCollections.filter().nameIsNull().findAll();
        if (unnamed.isEmpty) return (0, 0);
        final topCollections = await _isar.wordCollections
            .where()
            .folderIdIsNull()
            .filter()
            .nameIsNotNull()
            .binnedAtIsNull()
            .findAll();
        final topFolders = await _isar.collectionFolders
            .filter()
            .parentIdIsNull()
            .binnedAtIsNull()
            .findAll();
        var next = 0;
        for (final o in [
          for (final c in topCollections) c.order,
          for (final f in topFolders) f.order,
        ]) {
          if (o >= next) next = o + 1;
        }
        var fromId = 0;
        final moments = <int, DateTime>{};
        for (final c in unnamed) {
          final fromIdMoment = creationMomentOf(c.collectionId);
          if (fromIdMoment != null) fromId++;
          moments[c.id] = fromIdMoment ?? _earliestMomentOf(c);
        }
        unnamed.sort((a, b) {
          final byMoment = moments[a.id]!.compareTo(moments[b.id]!);
          return byMoment != 0 ? byMoment : a.id.compareTo(b.id);
        });
        for (final c in unnamed) {
          c
            ..name = defaultCollectionName(moments[c.id]!)
            ..folderId = null
            ..order = next++
            ..keep = !c.isEmpty;
        }
        await _isar.wordCollections.putAll(unnamed);
        return (fromId, unnamed.length - fromId);
      });
      if (fromId + fallback > 0) {
        debugPrint('VOCAB: backfill named ${fromId + fallback} '
            '(from id: $fromId, fallback: $fallback)');
      }
    } catch (e) {
      debugPrint('VOCAB: backfill failed, retried on the next open: $e');
    }
  }

  /// The earliest of [c]'s times, for an id with no readable moment
  /// (AC-04). A source's `takenAt` left at its 1970 default says nothing
  /// and is skipped.
  static DateTime _earliestMomentOf(WordCollection c) {
    var earliest = c.updatedAt;
    for (final t in [
      c.lastLocalModifiedAt,
      for (final s in c.sources)
        if (s.takenAt.millisecondsSinceEpoch > 0) s.takenAt,
    ]) {
      if (t.isBefore(earliest)) earliest = t;
    }
    return earliest;
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

  /// True when [c] is in the bin, directly or through a folder above it.
  Future<bool> isBinned(WordCollection c) async {
    try {
      final folders = await _isar.collectionFolders.where().findAll();
      return isInBin(
        binned: c.binnedAt != null,
        folderId: c.folderId,
        parentOf: {for (final f in folders) f.folderId: f.parentId},
        binnedFolderIds: {
          for (final f in folders)
            if (f.binnedAt != null) f.folderId,
        },
      );
    } catch (_) {
      return false;
    }
  }

  /// The collection with the newest `lastLocalModifiedAt` that is outside the
  /// bin (empty ones count), or null when there is none.
  Future<WordCollection?> newestOutsideBin() async {
    try {
      final all = await _isar.wordCollections
          .where()
          .sortByLastLocalModifiedAtDesc()
          .findAll();
      for (final c in all) {
        if (!await isBinned(c)) return await _withRowIds(c);
      }
    } catch (_) {}
    return null;
  }

  /// The id of every stored collection, binned ones too: a story run whose
  /// collection is not here was erased (collections-screen T20).
  Future<Set<String>> allIds() async {
    try {
      return (await _isar.wordCollections.where().collectionIdProperty().findAll()).toSet();
    } catch (_) {
      return const {};
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

  /// The stored name of collection [id] (null before the backfill or when
  /// it is gone), on listen and after every write (the main screen's title).
  Stream<String?> watchName(String id) =>
      _watchFiling(() async => (await _collectionById(id))?.name);

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

  // ---- Recycle bin (T9) ----
  //
  // ADR-0005: deleting marks the one item (`binnedAt`, `binnedFromFolderId`);
  // what a binned folder holds carries no mark. Erasing deletes an item and
  // everything inside in one transaction, then its `source_photos/` files;
  // `mnemonic_pictures/` and story runs are never touched.

  /// Marks [id] as deleted at [now] (the clock when null). Refuses the
  /// current collection, re-reading the pointer inside the transaction
  /// (AC-20). A folder holding the current collection, at any depth, first
  /// sends that collection to the folder's old place and its name comes back
  /// as `stayedName` (AC-21).
  Future<({BinResult result, String? stayedName})> bin(String id,
      {DateTime? now}) async {
    String? stayedName;
    try {
      final result = await _isar.writeTxn(() async {
        final binnedAt = now ?? DateTime.now();
        final current = await currentCollectionId();
        final collection = await _collectionById(id);
        final folder = collection == null ? await _folderById(id) : null;
        if (collection == null && folder == null) return BinResult.notFound;
        if ((collection?.binnedAt ?? folder?.binnedAt) != null) {
          return BinResult.notFound;
        }
        if (collection != null) {
          if (collection.collectionId == current) {
            return BinResult.refusedCurrent;
          }
          await _isar.wordCollections.put(collection
            ..binnedAt = binnedAt
            ..binnedFromFolderId = collection.folderId);
          await _closeLevel(collection.folderId);
          return BinResult.done;
        }
        final f = folder!;
        if (current != null) {
          final folders = await _isar.collectionFolders.where().findAll();
          final inside = {
            f.folderId,
            ...descendantsOf(
                f.folderId, {for (final x in folders) x.folderId: x.parentId}),
          };
          final cur = await _collectionById(current);
          if (cur != null && inside.contains(cur.folderId)) {
            await _isar.wordCollections.put(cur..folderId = f.parentId);
            await _placeInLevel(f.parentId, cur.collectionId, at: f.order);
            stayedName = LevelItem.collection(cur).name;
          }
        }
        final fresh = (await _folderById(id))!;
        await _isar.collectionFolders.put(fresh
          ..binnedAt = binnedAt
          ..binnedFromFolderId = fresh.parentId);
        await _closeLevel(fresh.parentId);
        return BinResult.done;
      });
      if (result == BinResult.refusedCurrent) {
        debugPrint('VOCAB: bin refused, $id is the current collection');
      }
      return (result: result, stayedName: stayedName);
    } catch (_) {
      return (result: BinResult.failed, stayedName: null);
    }
  }

  /// Takes [id] out of the bin (AC-24): into the folder it came from, or the
  /// top level when that folder is binned or gone, at its old order when it
  /// still fits, else at the end. `folderName` is null for the top level
  /// ("Restored to Collections").
  Future<({BinResult result, String? folderId, String? folderName})> restore(
      String id) async {
    const failed = (result: BinResult.failed, folderId: null, folderName: null);
    try {
      return await _isar.writeTxn(() async {
        final collection = await _collectionById(id);
        final folder = collection == null ? await _folderById(id) : null;
        final from =
            collection?.binnedFromFolderId ?? folder?.binnedFromFolderId;
        if ((collection?.binnedAt ?? folder?.binnedAt) == null) {
          return (result: BinResult.notFound, folderId: null, folderName: null);
        }
        final usable = from != null && await _folderUsable(from);
        final target = restoreTarget(
          binnedFromFolderId: from,
          folderUsable: usable,
          oldOrder: collection?.order ?? folder!.order,
          levelLength: (await _readLevel(usable ? from : null)).length,
        );
        if (collection != null) {
          await _isar.wordCollections.put(collection
            ..binnedAt = null
            ..binnedFromFolderId = null
            ..folderId = target.folderId);
        } else {
          await _isar.collectionFolders.put(folder!
            ..binnedAt = null
            ..binnedFromFolderId = null
            ..parentId = target.folderId);
        }
        await _placeInLevel(target.folderId, id, at: target.order);
        final name = target.folderId == null
            ? null
            : (await _folderById(target.folderId!))?.name;
        return (
          result: BinResult.done,
          folderId: target.folderId,
          folderName: name
        );
      });
    } catch (_) {
      return failed;
    }
  }

  /// Erases the items [ids] and everything inside them in the transaction
  /// that is running; returns the source photos of the collections deleted.
  Future<List<SessionSource>> _eraseInside(Iterable<String> ids) async {
    final folders = await _isar.collectionFolders.where().findAll();
    final parentOf = {for (final f in folders) f.folderId: f.parentId};
    final folderIds = <String>{};
    final collectionIds = <String>{};
    for (final id in ids) {
      if (parentOf.containsKey(id)) {
        folderIds
          ..add(id)
          ..addAll(descendantsOf(id, parentOf));
      } else {
        collectionIds.add(id);
      }
    }
    final photos = <SessionSource>[];
    for (final c in await _isar.wordCollections.where().findAll()) {
      if (collectionIds.contains(c.collectionId) ||
          folderIds.contains(c.folderId)) {
        photos.addAll(c.sources.where((s) => s.fileName.isNotEmpty));
        await _isar.wordCollections.delete(c.id);
      }
    }
    for (final f in folders) {
      if (folderIds.contains(f.folderId)) {
        await _isar.collectionFolders.delete(f.id);
      }
    }
    return photos;
  }

  /// Deletes the files of [photos] once the erasing transaction committed.
  Future<void> _deletePhotoFiles(List<SessionSource> photos) async {
    final store = SourcePhotoStore(directory: _isar.directory);
    for (final p in photos) {
      await store.delete(p);
    }
  }

  /// Erases the bin items [ids] for good; the files follow the commit.
  Future<int> _erase(bool Function(DateTime? binnedAt) wanted,
      {String? only}) async {
    try {
      final photos = <SessionSource>[];
      final count = await _isar.writeTxn(() async {
        final ids = <String>[
          for (final c in await _isar.wordCollections
              .filter()
              .binnedAtIsNotNull()
              .findAll())
            if ((only == null || only == c.collectionId) && wanted(c.binnedAt))
              c.collectionId,
          for (final f in await _isar.collectionFolders
              .filter()
              .binnedAtIsNotNull()
              .findAll())
            if ((only == null || only == f.folderId) && wanted(f.binnedAt))
              f.folderId,
        ];
        photos.addAll(await _eraseInside(ids));
        return ids.length;
      });
      await _deletePhotoFiles(photos);
      return count;
    } catch (_) {
      return -1;
    }
  }

  /// Deletes a bin item and everything inside it for good (AC-25).
  Future<BinResult> erase(String id) async {
    final n = await _erase((_) => true, only: id);
    return n < 0
        ? BinResult.failed
        : n == 0
            ? BinResult.notFound
            : BinResult.done;
  }

  /// Erases the whole bin in one transaction.
  Future<BinResult> emptyBin() async =>
      await _erase((_) => true) < 0 ? BinResult.failed : BinResult.done;

  /// Erases the bin items whose 30 x 24 h are up at [now] (AC-26); a clock
  /// moved backwards erases nothing early. Returns how many items went, 0 on
  /// a failed write.
  Future<int> sweepBin(DateTime now) async {
    // A read first: most opens have nothing to erase, and then no write
    // transaction is taken.
    try {
      final binned = [
        for (final c
            in await _isar.wordCollections.filter().binnedAtIsNotNull().findAll())
          c.binnedAt!,
        for (final f in await _isar.collectionFolders
            .filter()
            .binnedAtIsNotNull()
            .findAll())
          f.binnedAt!,
      ];
      if (!binned.any((at) => isExpired(at, now))) return 0;
    } catch (_) {
      return 0;
    }
    final n = await _erase((at) => at != null && isExpired(at, now));
    debugPrint('VOCAB: bin sweep erased ${n < 0 ? 0 : n} item(s)');
    return n < 0 ? 0 : n;
  }

  /// The items in the bin, newest `binnedAt` first (SCR-08).
  Stream<List<LevelItem>> watchBin() => _watchFiling(() async {
        final items = <LevelItem>[
          for (final f in await _isar.collectionFolders
              .filter()
              .binnedAtIsNotNull()
              .findAll())
            LevelItem.folder(f),
          for (final c in await _isar.wordCollections
              .filter()
              .binnedAtIsNotNull()
              .findAll())
            LevelItem.collection(c),
        ];
        return items..sort((a, b) => b.binnedAt!.compareTo(a.binnedAt!));
      });

  /// What binning [id] would take along (SCR-07); null when there is no such
  /// item. The current collection inside a folder is not counted: it stays.
  Future<BinPreview?> binPreview(String id) async {
    final collection = await _collectionById(id);
    if (collection != null) {
      return (
        name: LevelItem.collection(collection).name,
        isFolder: false,
        wordCount: LevelItem.collection(collection).wordCount,
        collections: 0,
        folders: 0,
        currentStaysName: null,
      );
    }
    final folder = await _folderById(id);
    if (folder == null) return null;
    final folders = await _isar.collectionFolders.where().findAll();
    final inner =
        descendantsOf(id, {for (final f in folders) f.folderId: f.parentId});
    final current = await currentCollectionId();
    var collections = 0;
    String? stays;
    for (final c in await _isar.wordCollections.where().findAll()) {
      if (c.folderId != id && !inner.contains(c.folderId)) continue;
      if (c.collectionId == current) {
        stays = LevelItem.collection(c).name;
      } else if (c.binnedAt == null) {
        collections++;
      }
    }
    return (
      name: folder.name,
      isFolder: true,
      wordCount: 0,
      collections: collections,
      folders: folders
          .where((f) => inner.contains(f.folderId) && f.binnedAt == null)
          .length,
      currentStaysName: stays,
    );
  }

  /// Whether [id], or anything inside it when it is a folder, has a shared
  /// link (`publishedId` set), for SCR-10's sentence.
  Future<bool> hasSharedLink(String id) async {
    final folders = await _isar.collectionFolders.where().findAll();
    final inside = {
      id,
      ...descendantsOf(id, {for (final f in folders) f.folderId: f.parentId}),
    };
    for (final c in await _isar.wordCollections.where().findAll()) {
      if ((c.collectionId == id || inside.contains(c.folderId)) &&
          (c.publishedId?.isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  // ---- end of Recycle bin (T9) ----

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

  Future<String?> currentCollectionId() async =>
      _prefs.getString(_currentCollectionKey);

  Future<void> setCurrentCollectionId(String collectionId) async {
    await _prefs.setString(_currentCollectionKey, collectionId);
  }
}
