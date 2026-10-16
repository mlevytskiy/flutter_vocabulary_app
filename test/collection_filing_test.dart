import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

import 'seed_collections.dart';

/// collections-screen T8: the filing transactions (rename, new folder, move,
/// reorder) and the level, folder and History streams, over a temp Isar.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_filing_test');
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

  Future<String> newFolder(String name, {String? parentId}) async {
    final r = await store.createFolder(parentId: parentId, name: name);
    expect(r.result, FilingResult.done);
    return r.folder!.folderId;
  }

  List<String> ids(List<LevelItem> items) => [for (final i in items) i.id];

  Future<T> next<T>(Stream<T> s, bool Function(T) until) =>
      s.firstWhere(until).timeout(const Duration(seconds: 2));

  group('rename', () {
    test('a collection: writes the name and raises keep, nothing else',
        () async {
      final c = await store.create();
      final before = await stored(c.collectionId);
      expect(await store.rename(c.collectionId, 'Phrasal verbs'),
          FilingResult.done);
      final after = await stored(c.collectionId);
      expect(after.name, 'Phrasal verbs');
      expect(after.keep, isTrue);
      expect(after.order, before.order);
      expect(after.folderId, before.folderId);
      expect(after.lastLocalModifiedAt, before.lastLocalModifiedAt);
      expect(after.updatedAt, before.updatedAt);
    });

    test('a folder: writes the name', () async {
      final f = await newFolder('English');
      expect(await store.rename(f, 'English course'), FilingResult.done);
      expect((await folder(f)).name, 'English course');
    });

    test('refuses an invalid name and writes nothing', () async {
      final c = await store.create();
      final f = await newFolder('English');
      for (final bad in ['', '   ', 'a\nb', 'x' * 61]) {
        expect(await store.rename(c.collectionId, bad),
            FilingResult.invalidName);
        expect(await store.rename(f, bad), FilingResult.invalidName);
      }
      expect((await stored(c.collectionId)).keep, isFalse);
      expect((await folder(f)).name, 'English');
    });

    test('refuses an unknown id', () async {
      expect(await store.rename('nope', 'Name'), FilingResult.notFound);
    });
  });

  group('createFolder', () {
    test('appends at the end of its level', () async {
      final a = await store.create();
      final top = await newFolder('Top');
      final f = await store.createFolder(parentId: top, name: 'Unit 3');
      expect(f.result, FilingResult.done);
      expect(f.folder!.name, 'Unit 3');
      expect(f.folder!.parentId, top);
      expect(f.folder!.order, 0);
      final b = await newFolder('Second');
      expect((await stored(a.collectionId)).order, 0);
      expect((await folder(top)).order, 1);
      expect((await folder(b)).order, 2);
    });

    test('refuses an invalid name', () async {
      final r = await store.createFolder(name: ' ');
      expect(r.result, FilingResult.invalidName);
      expect(r.folder, isNull);
      expect(await isar().collectionFolders.count(), 0);
    });

    test('refuses a parent that does not exist', () async {
      final r = await store.createFolder(parentId: 'nope', name: 'Unit');
      expect(r.result, FilingResult.notFound);
      expect(await isar().collectionFolders.count(), 0);
    });
  });

  group('move', () {
    test('a collection into a folder: renumbers both levels, raises keep',
        () async {
      final a = await store.create();
      final b = await store.create();
      final f = await newFolder('Folder');
      final inside = await store.create(folderId: f);
      expect(await store.move(a.collectionId, f, at: 0), FilingResult.done);
      final moved = await stored(a.collectionId);
      expect(moved.folderId, f);
      expect(moved.order, 0);
      expect(moved.keep, isTrue);
      expect((await stored(inside.collectionId)).order, 1);
      expect((await stored(b.collectionId)).order, 0);
      expect((await folder(f)).order, 1);
    });

    test('without at goes to the end; to null goes to the top level',
        () async {
      final f = await newFolder('Folder');
      final c = await store.create(folderId: f);
      await store.create();
      expect(await store.move(c.collectionId, null), FilingResult.done);
      final moved = await stored(c.collectionId);
      expect(moved.folderId, isNull);
      expect(moved.order, 2);
    });

    test('a folder takes its contents along', () async {
      final a = await newFolder('A');
      final b = await newFolder('B');
      final child = await newFolder('Child', parentId: a);
      final c = await store.create(folderId: a);
      expect(await store.move(a, b), FilingResult.done);
      expect((await folder(a)).parentId, b);
      expect((await folder(b)).order, 0);
      expect((await folder(child)).parentId, a);
      expect((await stored(c.collectionId)).folderId, a);
    });

    test('refuses a folder into itself or a descendant at any depth',
        () async {
      final a = await newFolder('English course');
      final b = await newFolder('Unit', parentId: a);
      final c = await newFolder('Lesson', parentId: b);
      for (final target in [a, b, c]) {
        expect(await store.move(a, target), FilingResult.intoItself);
      }
      expect((await folder(a)).parentId, isNull);
      expect((await folder(a)).order, 0);
    });

    test('refuses an unknown item or target', () async {
      final c = await store.create();
      expect(await store.move('nope', null), FilingResult.notFound);
      expect(await store.move(c.collectionId, 'nope'), FilingResult.notFound);
      expect((await stored(c.collectionId)).folderId, isNull);
    });
  });

  group('reorder', () {
    test('within its level, folders and collections share one order',
        () async {
      final a = await store.create();
      final f = await newFolder('F');
      final b = await store.create();
      expect(await store.reorder(b.collectionId, 0), FilingResult.done);
      expect((await stored(b.collectionId)).order, 0);
      expect((await stored(a.collectionId)).order, 1);
      expect((await folder(f)).order, 2);
      expect((await stored(b.collectionId)).keep, isTrue);
      expect(await store.reorder(f, 0), FilingResult.done);
      expect((await folder(f)).order, 0);
      expect((await stored(b.collectionId)).order, 1);
      expect((await stored(a.collectionId)).order, 2);
    });

    test('refuses an unknown id', () async {
      expect(await store.reorder('nope', 0), FilingResult.notFound);
    });
  });

  group('watchLevel', () {
    test('emits the level by order, skips binned items, and re-emits',
        () async {
      final a = await store.create();
      final f = await newFolder('F');
      final b = await store.create();
      await isar().writeTxn(() async {
        final binned = WordCollection.create()
          ..binnedAt = DateTime.now()
          ..order = 3;
        await isar().wordCollections.put(binned);
      });
      final level = store.watchLevel(null).asBroadcastStream();
      final first = await next(level, (_) => true);
      expect(ids(first), [a.collectionId, f, b.collectionId]);
      expect(first[1].isFolder, isTrue);
      expect(first[1].name, 'F');

      final reordered = next(level,
          (l) => ids(l).isNotEmpty && ids(l).first == b.collectionId);
      await store.reorder(b.collectionId, 0);
      expect(ids(await reordered), [b.collectionId, a.collectionId, f]);

      final renamed = next(level, (l) => l.any((i) => i.name == 'G'));
      await store.rename(f, 'G');
      await renamed;

      final moved = next(level, (l) => l.length == 2);
      await store.move(a.collectionId, f);
      expect(ids(await moved), [b.collectionId, f]);

      final created = next(level, (l) => l.length == 3);
      await store.createFolder(name: 'H');
      expect((await created).last.name, 'H');
    });

    test('inside a folder, with word counts', () async {
      final f = await newFolder('F');
      final c = await store.create(folderId: f);
      await store.put((await stored(c.collectionId))
        ..words = [
          WordPair(word: 'a', translation: 'а'),
          WordPair(word: 'b', translation: 'б'),
          WordPair(),
        ]);
      final items = await next(store.watchLevel(f), (_) => true);
      expect(ids(items), [c.collectionId]);
      expect(items.single.wordCount, 2);
      expect(items.single.isFolder, isFalse);
    });

    test('sorts records with the Isar null order first, without failing',
        () async {
      final c = await store.create();
      final old = WordCollection.create()..order = -9223372036854775808;
      await seedCollection(store, old);
      final items = await next(store.watchLevel(null), (_) => true);
      expect(ids(items), [old.collectionId, c.collectionId]);
    });
  });

  test('watchFolders emits every folder and re-emits', () async {
    final folders = store.watchFolders().asBroadcastStream();
    expect(await next(folders, (_) => true), isEmpty);
    final one = next(folders, (l) => l.length == 1);
    final f = await newFolder('F');
    expect((await one).single.folderId, f);
    final child = next(folders, (l) => l.length == 2);
    await newFolder('C', parentId: f);
    expect((await child).firstWhere((x) => x.name == 'C').parentId, f);
  });

  group('watchHistory', () {
    test('non-empty collections outside the bin, newest first, re-emitted',
        () async {
      final f = await newFolder('Binned');
      final inner = await newFolder('Inner', parentId: f);
      WordCollection withWords(DateTime at, {String? folderId, bool bin = false}) =>
          WordCollection.create()
            ..words = [WordPair(word: 'w', translation: 'с')]
            ..lastLocalModifiedAt = at
            ..folderId = folderId
            ..binnedAt = bin ? at : null;
      final now = DateTime.now();
      final older = withWords(now.subtract(const Duration(days: 2)));
      final newer = withWords(now.subtract(const Duration(days: 1)));
      final binned = withWords(now, bin: true);
      final throughAncestor = withWords(now, folderId: inner);
      for (final c in [older, newer, binned, throughAncestor]) {
        await seedCollection(store, c);
      }
      await store.create(); // empty, never listed
      await isar().writeTxn(() async {
        final binnedFolder = await isar()
            .collectionFolders
            .filter()
            .folderIdEqualTo(f)
            .findFirst();
        await isar().collectionFolders.put(binnedFolder!..binnedAt = now);
      });

      final history = store.watchHistory().asBroadcastStream();
      final first = await next(history, (_) => true);
      expect([for (final c in first) c.collectionId],
          [newer.collectionId, older.collectionId]);

      final renamed = next(history,
          (l) => l.any((c) => c.name == 'Phrasal verbs'));
      await store.rename(older.collectionId, 'Phrasal verbs');
      await renamed;

      final unbinned = next(history, (l) => l.length == 3);
      await store.move(inner, null);
      expect((await unbinned).map((c) => c.collectionId),
          contains(throughAncestor.collectionId));
    });
  });
}
