import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';

/// collection-tags T7 (ADR-0006, AC-08, AC-27, AC-30, AC-38): the summaries
/// stream has every live collection, empty ones too, with folder path and
/// My order, and re-reads once per burst of writes.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_summaries_test');
    store = await CollectionStore.open(directory: dir.path);
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<List<CollectionSummary>> now() =>
      store.watchSummaries(debounce: Duration.zero).first;

  test('empty collections are included, with created from the id', () async {
    final c = await store.create(name: 'Empty one', topic: ['Food']);
    final list = await now();
    final s = list.singleWhere((x) => x.id == c.collectionId);
    expect(s.name, 'Empty one');
    expect(s.topicTags, ['Food']);
    expect(s.folderPath, 'Top level');
    expect(s.created, creationMomentOf(c.collectionId));
    expect(s.edited, c.updatedAt);
  });

  test('binned collections, directly or through a folder, are left out',
      () async {
    final keep = await store.create(name: 'Keep');
    final direct = await store.create(name: 'Direct');
    final folder = (await store.createFolder(name: 'F')).folder!;
    final inner =
        (await store.createFolder(parentId: folder.folderId, name: 'G'))
            .folder!;
    final deep = await store.create(name: 'Deep', folderId: inner.folderId);
    // Another collection becomes current, so the ones above may be binned.
    await store.setCurrentCollectionId(
        (await store.create(name: 'Current2')).collectionId);

    expect((await store.bin(direct.collectionId)).result, BinResult.done);
    expect((await store.bin(folder.folderId)).result, BinResult.done);

    final names = [for (final s in await now()) s.name];
    expect(names, contains('Keep'));
    expect(names, isNot(contains('Direct')));
    expect(names, isNot(contains('Deep')));
    expect(keep.collectionId, isNotEmpty);
    expect(deep.collectionId, isNotEmpty);
  });

  test('folder path and depth-first My order', () async {
    final a = (await store.createFolder(name: 'A')).folder!;
    final b =
        (await store.createFolder(parentId: a.folderId, name: 'B')).folder!;
    final top1 = await store.create(name: 'Top1');
    final inB = await store.create(name: 'InB', folderId: b.folderId);
    final inA = await store.create(name: 'InA', folderId: a.folderId);
    final top2 = await store.create(name: 'Top2');
    // Top level: A, Top1, Top2. A: B, InA.
    await store.move(a.folderId, null, at: 0);
    await store.move(top1.collectionId, null, at: 1);
    await store.move(top2.collectionId, null, at: 2);
    await store.move(b.folderId, a.folderId, at: 0);
    await store.move(inA.collectionId, a.folderId, at: 1);

    final list = await now();
    final byName = {for (final s in list) s.name: s};
    expect(byName['InB']!.folderPath, 'A / B');
    expect(byName['InA']!.folderPath, 'A');
    expect(byName['Top1']!.folderPath, 'Top level');
    final inOrder = [...list]
      ..sort((x, y) => x.treeIndex.compareTo(y.treeIndex));
    final order = [for (final s in inOrder) s.name]
        .where(const {'InB', 'InA', 'Top1', 'Top2'}.contains)
        .toList();
    expect(order, ['InB', 'InA', 'Top1', 'Top2']);
    expect({for (final s in list) s.treeIndex}.length, list.length);
    expect(inB.collectionId, isNotEmpty);
  });

  test('one emission per burst of writes', () async {
    final emissions = <List<CollectionSummary>>[];
    final sub = store
        .watchSummaries(debounce: const Duration(milliseconds: 200))
        .listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(emissions, hasLength(1)); // on listen

    for (var i = 0; i < 5; i++) {
      await store.create(name: 'N$i');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(emissions, hasLength(1)); // still waiting out the burst
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(emissions, hasLength(2));
    expect(emissions.last.where((s) => s.name.startsWith('N')), hasLength(5));
    await sub.cancel();
  });
}
