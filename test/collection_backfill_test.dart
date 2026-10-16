import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

/// collections-screen T6, AC-04, QG-2: the one-time filing backfill that
/// `CollectionStore.open` runs over every record with no name.
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
  late Isar isar;
  final logs = <String>[];
  final savedDebugPrint = debugPrint;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_backfill_test');
    // The store reuses an open `vocab` instance, so records seeded here are
    // what it finds on open, exactly like a database from an older build.
    isar = await Isar.open(
        [WordCollectionSchema, StoryRunSchema, CollectionFolderSchema],
        directory: dir.path, name: 'vocab');
    logs.clear();
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  });

  tearDown(() async {
    debugPrint = savedDebugPrint;
    if (isar.isOpen) await isar.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String idAt(DateTime t) =>
      '${t.microsecondsSinceEpoch.toRadixString(36)}-abc';

  WordPair word(String w) =>
      WordPair(word: w, translation: '$w-uk')..rowId = 'row-$w';

  /// A record as an older build wrote it: no name, no filing.
  WordCollection old(String id, DateTime t,
          {List<WordPair> words = const [],
          List<SessionSource> sources = const []}) =>
      WordCollection()
        ..collectionId = id
        ..updatedAt = t
        ..lastLocalModifiedAt = t
        ..words = [...words]
        ..sources = [...sources]
        ..tags = ['t-$id']
        ..results = [
          WordResult()
            ..rowId = 'r'
            ..at = t
        ];

  Future<void> seed(List<WordCollection> cs) =>
      isar.writeTxn(() => isar.wordCollections.putAll(cs));

  Future<WordCollection> read(String id) async => (await isar.wordCollections
      .filter()
      .collectionIdEqualTo(id)
      .findFirst())!;

  String content(WordCollection c) => jsonEncode(c.toJson());

  test(
      'names each unnamed record from its id, at the top level, oldest '
      'first, keep = has words; content unchanged', () async {
    final t1 = DateTime(2026, 3, 1, 9, 5);
    final t2 = DateTime(2026, 4, 2, 10, 15);
    final t3 = DateTime(2026, 5, 3, 11, 25);
    // Seeded out of order so the Isar id order is not the answer.
    final c3 = old(idAt(t3), DateTime(2026, 9, 9), words: [word('pear')]);
    final c1 = old(idAt(t1), DateTime(2026, 9, 9));
    final c2 = old(idAt(t2), DateTime(2026, 9, 9), words: [word('apple')]);
    await seed([c3, c1, c2]);
    final before = {
      for (final c in [c1, c2, c3])
        c.collectionId: content(await read(c.collectionId)),
    };

    await CollectionStore.open(directory: dir.path);

    final r1 = await read(c1.collectionId);
    final r2 = await read(c2.collectionId);
    final r3 = await read(c3.collectionId);
    expect(r1.name, defaultCollectionName(t1));
    expect(r2.name, defaultCollectionName(t2));
    expect(r3.name, defaultCollectionName(t3));
    expect([r1.order, r2.order, r3.order], [0, 1, 2]);
    expect([r1.folderId, r2.folderId, r3.folderId], [null, null, null]);
    expect([r1.keep, r2.keep, r3.keep], [false, true, true]);
    expect([r1.binnedAt, r2.binnedAt, r3.binnedAt], [null, null, null]);
    for (final r in [r1, r2, r3]) {
      expect(content(r), before[r.collectionId]);
    }
    expect(logs, contains('VOCAB: backfill named 3 (from id: 3, fallback: 0)'));
  });

  test(
      'an unparsable id falls back to the earliest of updatedAt, '
      'lastLocalModifiedAt and the sources\' takenAt', () async {
    final early = DateTime(2025, 1, 2, 3, 4);
    final bad = old('no_moment_here', DateTime(2026, 6, 1), sources: [
      SessionSource()
        ..id = 's1'
        ..takenAt = early,
    ])
      ..lastLocalModifiedAt = DateTime(2026, 7, 1);
    final bad2 = old('also bad', DateTime(2026, 2, 1))
      ..lastLocalModifiedAt = DateTime(2026, 1, 15, 8, 30);
    final good = old(idAt(DateTime(2025, 6, 1)), DateTime(2026, 9, 9));
    await seed([bad, bad2, good]);

    await CollectionStore.open(directory: dir.path);

    final rBad = await read(bad.collectionId);
    final rBad2 = await read(bad2.collectionId);
    final rGood = await read(good.collectionId);
    expect(rBad.name, defaultCollectionName(early));
    expect(rBad2.name, defaultCollectionName(DateTime(2026, 1, 15, 8, 30)));
    expect(rGood.name, defaultCollectionName(DateTime(2025, 6, 1)));
    // Oldest first by that moment: early (2025-01), good (2025-06), bad2.
    expect([rBad.order, rGood.order, rBad2.order], [0, 1, 2]);
    expect(logs, contains('VOCAB: backfill named 3 (from id: 1, fallback: 2)'));
  });

  test(
      'in a mixed store the unnamed records go after the filed top level; '
      'filed records and folders are left alone', () async {
    final filed = old(idAt(DateTime(2026, 8, 1)), DateTime(2026, 8, 1))
      ..name = 'Mine'
      ..order = 4
      ..keep = true;
    final inFolder = old(idAt(DateTime(2026, 8, 2)), DateTime(2026, 8, 2))
      ..name = 'Deep'
      ..folderId = 'f1'
      ..order = 9;
    final unnamed = old(idAt(DateTime(2020, 1, 1)), DateTime(2020, 1, 1));
    await seed([filed, inFolder, unnamed]);
    await isar.writeTxn(() => isar.collectionFolders.put(CollectionFolder()
      ..folderId = 'f1'
      ..name = 'Folder'
      ..order = 6));

    await CollectionStore.open(directory: dir.path);

    final rFiled = await read(filed.collectionId);
    expect((rFiled.name, rFiled.order, rFiled.keep), ('Mine', 4, true));
    expect((await read(inFolder.collectionId)).order, 9);
    expect((await isar.collectionFolders.where().findFirst())!.order, 6);
    final r = await read(unnamed.collectionId);
    expect(r.name, defaultCollectionName(DateTime(2020, 1, 1)));
    expect(r.folderId, isNull);
    expect(r.order, 7);
  });

  test('a second open writes nothing', () async {
    await seed([
      old(idAt(DateTime(2026, 1, 1)), DateTime(2026, 1, 1), words: [word('a')]),
      old('bad_id', DateTime(2026, 2, 1)),
    ]);
    await CollectionStore.open(directory: dir.path);
    final first = [
      for (final c in await isar.wordCollections.where().findAll())
        (content(c), c.name, c.order, c.keep, c.folderId),
    ];
    logs.clear();

    var writes = 0;
    final sub = isar.wordCollections.watchLazy().listen((_) => writes++);
    await CollectionStore.open(directory: dir.path);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(writes, 0);
    expect([
      for (final c in await isar.wordCollections.where().findAll())
        (content(c), c.name, c.order, c.keep, c.folderId),
    ], first);
    expect(logs.where((l) => l.startsWith('VOCAB: backfill')), isEmpty);
  });
}
