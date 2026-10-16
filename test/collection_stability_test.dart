import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/filing.dart';

/// collections-screen T10, QG-1 (sad §10), AC-27: name and place stability.
///
/// 100 seeded runs. Each run builds a small tree (2 folders, 6 collections,
/// one of them the current one), then starts at once, in a random order and
/// with random delays: background writers that call the REAL store methods
/// (autosave `put` from a stale whole copy read at the start of the run,
/// story/word-groups/dialogue-push/late-lookup `update`, exam `appendResult`)
/// and filing changes (rename, move, reorder, bin, erase). The expected
/// filing state is a model fed by the filing results in completion order
/// (each filing action is one write transaction, so completion order is
/// execution order). After the run, and again after closing and reopening
/// the store, the database must equal the model: no reverted name, place or
/// order, nothing back from the bin, nothing erased re-created.
///
/// One store (one Isar) serves all runs and is cleared between runs; it is
/// closed and reopened at the end of every run, because the reopen (with its
/// backfill) is part of what must keep the filing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  late Directory dir;
  late CollectionStore store;
  Isar isar() => Isar.getInstance('vocab')!;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('collection_stability_test');
  });
  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('100 seeded interleavings keep every name, place and order', () async {
    SharedPreferences.setMockInitialValues({});
    store = await CollectionStore.open(directory: dir.path);
    for (var seed = 0; seed < 100; seed++) {
      await _run(seed, () => store, (s) => store = s, dir.path, isar);
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}

/// The filing state of a tree: what the model predicts and what is stored.
class _Filing {
  final names = <String, String>{};
  final parents = <String, String?>{};
  final folders = <String>{};
  final binned = <String>{};
  // Live (not binned) items of each level, in order. Key null = top level.
  final levels = <String?, List<String>>{};

  Set<String> get all => parents.keys.toSet();

  void erase(String id) {
    final gone = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final e in parents.entries) {
        if (gone.contains(e.value) && gone.add(e.key)) grew = true;
      }
    }
    for (final g in gone) {
      names.remove(g);
      parents.remove(g);
      folders.remove(g);
      binned.remove(g);
      levels.remove(g);
    }
    for (final l in levels.values) {
      l.removeWhere(gone.contains);
    }
  }
}

Future<_Filing> _snapshot(Isar isar) async {
  final f = _Filing();
  final records = <({
    String id,
    String name,
    String? parent,
    DateTime? binned,
    int order,
    bool folder
  })>[
    for (final c in await isar.wordCollections.where().findAll())
      (
        id: c.collectionId,
        name: c.name ?? '?',
        parent: c.folderId,
        binned: c.binnedAt,
        order: c.order,
        folder: false
      ),
    for (final c in await isar.collectionFolders.where().findAll())
      (
        id: c.folderId,
        name: c.name,
        parent: c.parentId,
        binned: c.binnedAt,
        order: c.order,
        folder: true
      ),
  ];
  for (final r in records) {
    f.names[r.id] = r.name;
    f.parents[r.id] = r.parent;
    if (r.folder) f.folders.add(r.id);
    if (r.binned != null) f.binned.add(r.id);
  }
  final live = records.where((r) => r.binned == null).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  for (final r in live) {
    (f.levels[r.parent] ??= []).add(r.id);
  }
  // Orders must be exactly 0..n-1 in every level.
  for (final level in f.levels.entries) {
    final orders = [
      for (final id in level.value) live.firstWhere((r) => r.id == id).order,
    ];
    expect(orders, [for (var i = 0; i < orders.length; i++) i],
        reason: 'orders of level ${level.key} are not 0..n-1');
  }
  return f;
}

void _expectSame(_Filing model, _Filing db, String when) {
  expect(db.all, model.all,
      reason: '$when: re-created or missing records (erased must stay erased)');
  expect(db.names, model.names, reason: '$when: reverted names');
  expect(db.parents, model.parents, reason: '$when: reverted places');
  expect(db.binned, model.binned, reason: '$when: bin state changed');
  final keys = {...model.levels.keys, ...db.levels.keys};
  for (final k in keys) {
    expect(db.levels[k] ?? <String>[], model.levels[k] ?? <String>[],
        reason: '$when: reverted order in level $k');
  }
}

Future<void> _run(
    int seed,
    CollectionStore Function() getStore,
    void Function(CollectionStore) setStore,
    String dir,
    Isar Function() isar) async {
  final rnd = Random(seed);
  var store = getStore();
  final reason = 'seed $seed';

  // Fresh tree.
  await isar().writeTxn(() async {
    await isar().wordCollections.clear();
    await isar().collectionFolders.clear();
  });
  // The tree goes in with one transaction (setup must stay cheap): folders
  // 0 and 1 at the top; collections 0-3 at the top, 4 and 5 in the folders.
  final folderIds = [for (var i = 0; i < 2; i++) 'f$seed-$i'];
  final collIds = [for (var i = 0; i < 6; i++) 'c$seed-$i'];
  final stamp = DateTime.utc(2026, 1, 1);
  await isar().writeTxn(() async {
    for (var i = 0; i < 2; i++) {
      await isar().collectionFolders.put(CollectionFolder()
        ..folderId = folderIds[i]
        ..name = 'F$seed-$i'
        ..parentId = null
        ..order = 4 + i);
    }
    for (var i = 0; i < 6; i++) {
      await isar().wordCollections.put(WordCollection()
        ..collectionId = collIds[i]
        ..updatedAt = stamp
        ..lastLocalModifiedAt = stamp
        ..name = 'C$seed-$i'
        ..folderId = i >= 4 ? folderIds[i - 4] : null
        ..order = i >= 4 ? 0 : i
        ..keep = true
        ..words = [
          WordPair(word: 'w$i', translation: 't$i'),
          WordPair(word: 'x$i', translation: 'u$i'),
        ]);
    }
  });
  final current = collIds.first;
  await store.setCurrentCollectionId(current);

  final model = await _snapshot(isar());
  final everyone = [...folderIds, ...collIds];
  final staleCopies = {for (final id in collIds) id: (await store.byId(id))!};

  // Starts a future that sleeps a little first, so interleavings differ.
  Future<void> nap() =>
      Future<void>.delayed(Duration(microseconds: rnd.nextInt(2500)));

  final jobs = <Future<void> Function()>[];
  var counter = 0;
  String pick() => everyone[rnd.nextInt(everyone.length)];
  String pickColl() => collIds[rnd.nextInt(collIds.length)];

  // Background writers: several of each kind.
  for (var i = 0; i < 2; i++) {
    final id = pickColl();
    final stale = staleCopies[id]!;
    jobs.add(() async {
      // autosave: whole copy read earlier, plus a stale, wrong filing.
      await nap();
      stale.words = [WordPair(word: 'auto$i', translation: 'x')];
      stale.name = 'STALE ${stale.name}';
      stale.folderId = rnd.nextBool() ? null : folderIds[0];
      stale.order = 77;
      stale.binnedAt = null;
      stale.binnedFromFolderId = null;
      await store.put(stale);
    });
  }
  for (var i = 0; i < 2; i++) {
    final id = pickColl();
    jobs.add(() async {
      // story-ish / word groups / dialogue push / late lookup: update().
      await nap();
      await store.update(id, (c) {
        c.selectedGroupId = 'g$i';
        c.groupedWordsKey = 'k$i';
        c.tags = ['t$i'];
        if (c.words.isNotEmpty) c.words.first.translation = 'late$i';
        // A careless writer touching filing must still change nothing.
        if (i.isOdd) {
          c.name = 'LEAK';
          c.folderId = folderIds[1];
          c.binnedAt = null;
          c.order = 55;
        }
      });
    });
  }
  for (var i = 0; i < 1; i++) {
    final id = pickColl();
    jobs.add(() async {
      await nap();
      await store.appendResult(
          id,
          WordResult()
            ..rowId = 'r$i'
            ..exerciseId = 'quiz');
    });
  }

  // Filing changes whose results feed the model, in completion order.
  void onDone(Object result, void Function() apply) {
    if (result == FilingResult.done || result == BinResult.done) apply();
  }

  for (var i = 0; i < 9; i++) {
    final id = pick();
    switch (rnd.nextInt(5)) {
      case 0:
        final name = 'R$seed-${counter++}';
        jobs.add(() async {
          await nap();
          onDone(await store.rename(id, name), () => model.names[id] = name);
        });
      case 1:
        // The current collection stays at the top (relocating it is T9's
        // test, AC-21); everything else may go anywhere, even nowhere valid.
        if (id == current) continue;
        final target = rnd.nextInt(3) == 0
            ? null
            : folderIds[rnd.nextInt(folderIds.length)];
        final at = rnd.nextBool() ? null : rnd.nextInt(4);
        jobs.add(() async {
          await nap();
          onDone(await store.move(id, target, at: at), () {
            model.levels[model.parents[id]]?.remove(id);
            model.parents[id] = target;
            model.levels[target] =
                placeInLevel(model.levels[target] ?? [], id, at: at);
          });
        });
      case 2:
        final index = rnd.nextInt(4);
        jobs.add(() async {
          await nap();
          onDone(await store.reorder(id, index), () {
            final p = model.parents[id];
            model.levels[p] =
                placeInLevel(model.levels[p] ?? [], id, at: index);
          });
        });
      case 3:
        jobs.add(() async {
          await nap();
          final r = await store.bin(id);
          onDone(r.result, () {
            model.binned.add(id);
            model.levels[model.parents[id]]?.remove(id);
          });
        });
      default:
        jobs.add(() async {
          await nap();
          onDone(await store.erase(id), () => model.erase(id));
        });
    }
  }

  // Start all, in a random order; await in another random order.
  jobs.shuffle(rnd);
  final started = [for (final j in jobs) j()];
  started.shuffle(rnd);
  for (final f in started) {
    await f;
  }

  _expectSame(model, await _snapshot(isar()), '$reason after run');
  // The current collection was never binned or erased.
  expect(model.binned.contains(current), isFalse, reason: reason);
  expect(model.all.contains(current), isTrue, reason: reason);

  await store.close();
  store = await CollectionStore.open(directory: dir);
  setStore(store);
  _expectSame(model, await _snapshot(isar()), '$reason after reopen');
}
