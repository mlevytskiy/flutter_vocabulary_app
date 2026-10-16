import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/filing.dart' show binRetention;

/// collections-screen T9: bin, restore, erase, empty and the 30-day sweep.
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
  final t0 = DateTime(2026, 10, 1, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_bin_test');
    store = await CollectionStore.open(directory: dir.path);
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<WordCollection> stored(String id) async => (await store.byId(id))!;
  Future<CollectionFolder> folder(String id) async => (await isar()
      .collectionFolders
      .filter()
      .folderIdEqualTo(id)
      .findFirst())!;
  Future<String> newFolder(String name, {String? parentId}) async =>
      (await store.createFolder(parentId: parentId, name: name))
          .folder!
          .folderId;
  Future<String> newCollection({String? folderId}) async =>
      (await store.create(folderId: folderId, keep: true)).collectionId;
  List<String> ids(List<LevelItem> l) => [for (final i in l) i.id];

  File photoFile(String name) {
    final d = Directory('${dir.path}/source_photos')..createSync(recursive: true);
    return File('${d.path}/$name')..writeAsStringSync('jpg');
  }

  Future<void> withPhoto(String collectionId, String fileName) async {
    final c = await stored(collectionId);
    c.sources = [
      SessionSource()
        ..id = fileName
        ..fileName = fileName
    ];
    c.words = [WordPair(word: 'a', translation: 'b')];
    await store.put(c);
  }

  group('bin', () {
    test('marks one collection and closes the gap', () async {
      final a = await newCollection();
      final b = await newCollection();
      final c = await newCollection();
      final r = await store.bin(b, now: t0);
      expect(r.result, BinResult.done);
      final s = await stored(b);
      expect(s.binnedAt, t0);
      expect(s.binnedFromFolderId, isNull);
      expect(ids(await store.watchLevel(null).first), [a, c]);
      expect((await stored(c)).order, 1);
    });

    test('remembers the folder it came from', () async {
      final f = await newFolder('F');
      final a = await newCollection(folderId: f);
      await store.bin(a, now: t0);
      expect((await stored(a)).binnedFromFolderId, f);
    });

    test('refuses the current collection', () async {
      final a = await newCollection();
      await store.setCurrentCollectionId(a);
      final r = await store.bin(a, now: t0);
      expect(r.result, BinResult.refusedCurrent);
      expect((await stored(a)).binnedAt, isNull);
    });

    test('a folder is marked alone; its contents carry no mark', () async {
      final f = await newFolder('F');
      final a = await newCollection(folderId: f);
      expect((await store.bin(f, now: t0)).result, BinResult.done);
      expect((await folder(f)).binnedAt, t0);
      expect((await stored(a)).binnedAt, isNull);
      expect(await store.watchHistory().first, isEmpty);
    });

    test('a folder holding the current collection moves it to its old place',
        () async {
      final x = await newCollection();
      final f = await newFolder('F');
      final inner = await newFolder('G', parentId: f);
      final cur = await newCollection(folderId: inner);
      final y = await newCollection();
      await store.setCurrentCollectionId(cur);
      final r = await store.bin(f, now: t0);
      expect(r.result, BinResult.done);
      expect(r.stayedName, (await stored(cur)).name);
      expect((await stored(cur)).folderId, isNull);
      expect((await folder(f)).binnedAt, t0);
      expect(ids(await store.watchLevel(null).first), [x, cur, y]);
    });

    test('unknown or already binned is notFound', () async {
      final a = await newCollection();
      expect((await store.bin('nope')).result, BinResult.notFound);
      await store.bin(a, now: t0);
      expect((await store.bin(a)).result, BinResult.notFound);
    });
  });

  group('restore', () {
    test('back to the old folder at the old order', () async {
      final f = await newFolder('F');
      final a = await newCollection(folderId: f);
      final b = await newCollection(folderId: f);
      final c = await newCollection(folderId: f);
      await store.bin(a, now: t0);
      final r = await store.restore(a);
      expect(r.result, BinResult.done);
      expect(r.folderId, f);
      expect(r.folderName, 'F');
      expect((await stored(a)).binnedAt, isNull);
      expect(ids(await store.watchLevel(f).first), [a, b, c]);
    });

    test('when the old order no longer fits it goes to the end', () async {
      final a = await newCollection();
      final b = await newCollection();
      final c = await newCollection();
      await store.bin(c, now: t0);
      await store.bin(b, now: t0);
      await store.restore(c); // level is [a]; order 2 > 1 -> end
      expect(ids(await store.watchLevel(null).first), [a, c]);
    });

    test('a binned or gone folder means top level', () async {
      final f = await newFolder('F');
      final a = await newCollection(folderId: f);
      final b = await newCollection(folderId: f);
      await store.bin(a, now: t0);
      await store.bin(f, now: t0);
      final r = await store.restore(a);
      expect(r.folderId, isNull);
      expect(r.folderName, isNull);
      expect((await stored(a)).folderId, isNull);
      await store.bin(b, now: t0);
      await isar().writeTxn(
          () async => isar().collectionFolders.delete((await folder(f)).id));
      final r2 = await store.restore(b);
      expect(r2.result, BinResult.done);
      expect((await stored(b)).folderId, isNull);
    });

    test('a folder restores with its contents', () async {
      final f = await newFolder('F');
      final a = await newCollection(folderId: f);
      await store.bin(f, now: t0);
      expect((await store.restore(f)).result, BinResult.done);
      expect(ids(await store.watchLevel(null).first), [f]);
      expect(ids(await store.watchLevel(f).first), [a]);
    });

    test('not in the bin is notFound', () async {
      final a = await newCollection();
      expect((await store.restore(a)).result, BinResult.notFound);
    });
  });

  group('erase', () {
    test('deletes a folder with everything inside, files after commit',
        () async {
      final f = await newFolder('F');
      final g = await newFolder('G', parentId: f);
      final a = await newCollection(folderId: g);
      final keepMe = await newCollection();
      await withPhoto(a, 'a.jpg');
      final mn = File('${dir.path}/mnemonic_pictures/m.png')
        ..createSync(recursive: true);
      final pFile = File('${dir.path}/source_photos/a.jpg');
      expect(photoFile('a.jpg').existsSync(), isTrue);
      await store.bin(f, now: t0);
      expect(await store.erase(f), BinResult.done);
      expect(await store.byId(a), isNull);
      expect(await isar().collectionFolders.count(), 0);
      expect(await store.byId(keepMe), isNotNull);
      expect(pFile.existsSync(), isFalse);
      expect(mn.existsSync(), isTrue);
    });

    test('files stay when the transaction does not commit', () async {
      final a = await newCollection();
      await withPhoto(a, 'a.jpg');
      photoFile('a.jpg');
      // not binned: nothing is erased, nothing is removed
      expect(await store.erase(a), BinResult.notFound);
      expect(File('${dir.path}/source_photos/a.jpg').existsSync(), isTrue);
    });

    test('story runs are never deleted', () async {
      final a = await newCollection();
      await isar().writeTxn(() async {
        await isar().storyRuns.put(StoryRun()
          ..runId = 'r1'
          ..collectionId = a
          ..groupId = 'g'
          ..groupName = 'G'
          ..startedAt = t0);
      });
      await store.bin(a, now: t0);
      await store.erase(a);
      expect(await isar().storyRuns.count(), 1);
    });

    test('emptyBin erases every bin item and leaves the rest', () async {
      final a = await newCollection();
      final f = await newFolder('F');
      final b = await newCollection(folderId: f);
      final c = await newCollection();
      await store.bin(a, now: t0);
      await store.bin(f, now: t0);
      expect(await store.emptyBin(), BinResult.done);
      expect(await store.byId(a), isNull);
      expect(await store.byId(b), isNull);
      expect(await store.byId(c), isNotNull);
      expect(await store.watchBin().first, isEmpty);
    });
  });

  group('sweepBin', () {
    test('erases only items whose 30 x 24 h are up', () async {
      final old = await newCollection();
      final young = await newCollection();
      await store.bin(old, now: t0);
      await store.bin(young, now: t0.add(const Duration(days: 1)));
      final edge = t0.add(binRetention);
      expect(await store.sweepBin(edge.subtract(const Duration(seconds: 1))), 0);
      expect(await store.sweepBin(edge), 1);
      expect(await store.byId(old), isNull);
      expect(await store.byId(young), isNotNull);
    });

    test('a clock moved backwards erases nothing', () async {
      final a = await newCollection();
      await store.bin(a, now: t0);
      expect(await store.sweepBin(t0.subtract(const Duration(days: 90))), 0);
      expect(await store.byId(a), isNotNull);
    });

    test('removes the photo files of what it erased', () async {
      final a = await newCollection();
      await withPhoto(a, 'z.jpg');
      photoFile('z.jpg');
      await store.bin(a, now: t0);
      await store.sweepBin(t0.add(binRetention));
      expect(File('${dir.path}/source_photos/z.jpg').existsSync(), isFalse);
    });
  });

  group('watchBin, binPreview, hasSharedLink', () {
    test('watchBin lists bin items newest first', () async {
      final a = await newCollection();
      final f = await newFolder('F');
      final b = await newCollection();
      await store.bin(a, now: t0);
      await store.bin(f, now: t0.add(const Duration(hours: 2)));
      await store.bin(b, now: t0.add(const Duration(hours: 1)));
      final items = await store.watchBin().first;
      expect(ids(items), [f, b, a]);
      expect(items.first.binnedAt, t0.add(const Duration(hours: 2)));
    });

    test('binPreview counts what goes with a folder and names the current',
        () async {
      final f = await newFolder('F');
      final g = await newFolder('G', parentId: f);
      await newCollection(folderId: f);
      await newCollection(folderId: g);
      final cur = await newCollection(folderId: g);
      await store.setCurrentCollectionId(cur);
      final p = (await store.binPreview(f))!;
      expect(p.isFolder, isTrue);
      expect(p.name, 'F');
      expect(p.folders, 1);
      expect(p.collections, 2);
      expect(p.currentStaysName, (await stored(cur)).name);
      final one = (await store.binPreview(cur))!;
      expect(one.isFolder, isFalse);
      expect(await store.binPreview('nope'), isNull);
    });

    test('hasSharedLink looks at the item and its contents', () async {
      final f = await newFolder('F');
      final a = await newCollection(folderId: f);
      final b = await newCollection();
      expect(await store.hasSharedLink(f), isFalse);
      final c = await stored(a);
      await isar().writeTxn(() async {
        await isar().wordCollections.put(c..publishedId = 'pub1');
      });
      expect(await store.hasSharedLink(a), isTrue);
      expect(await store.hasSharedLink(f), isTrue);
      expect(await store.hasSharedLink(b), isFalse);
    });
  });
}
