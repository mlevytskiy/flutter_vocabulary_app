import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart' show BinResult;
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

/// learn-redesign T2 (ADR-0001, ADR-0002, sad §5.1): the Leitner boxes live on
/// the collection, round-trip through JSON, survive a stale words-table
/// [CollectionStore.put], change only through [CollectionStore.update], and
/// come back with a restored collection (AC-15).
/// One Isar store for the whole file (docs/testing.md rule 4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late CollectionStore store;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('learn_session_word_box_store_test');
    store = await CollectionStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final due = DateTime.utc(2026, 10, 24, 9);

  WordBox box(String rowId, String word, int n, {String lastUpDay = ''}) => WordBox()
    ..rowId = rowId
    ..word = word
    ..box = n
    ..dueAt = due
    ..lastUpDay = lastUpDay;

  /// A collection made through the store, with two words.
  Future<String> newCollection() async {
    final c = await store.create(keep: true);
    c.words = [
      WordPair(word: 'walk', translation: 'гуляти', rowId: 'r1'),
      WordPair(word: 'run', translation: 'бігти', rowId: 'r2'),
    ];
    await store.put(c);
    return c.collectionId;
  }

  test('a collection has no boxes until one is written; JSON round-trips them', () {
    final c = WordCollection.create();
    expect(c.boxes, isEmpty);
    c.boxes = [box('r1', 'walk', 3, lastUpDay: '2026-10-23')];
    final back = WordCollection.fromJson(c.toJson());
    final b = back.boxes.single;
    expect(b.rowId, 'r1');
    expect(b.word, 'walk');
    expect(b.box, 3);
    expect(b.dueAt, due);
    expect(b.lastUpDay, '2026-10-23');
    // JSON from before learn-redesign has no boxes.
    final old = c.toJson()..remove('boxes');
    expect(WordCollection.fromJson(old).boxes, isEmpty);
  });

  test('WordBox.copy is a separate object with the same fields', () {
    final a = box('r1', 'walk', 2, lastUpDay: '2026-10-22');
    final b = a.copy()..box = 4;
    expect(a.box, 2);
    expect(b.rowId, 'r1');
    expect(b.word, 'walk');
    expect(b.dueAt, due);
    expect(b.lastUpDay, '2026-10-22');
  });

  test('update() writes boxes; put() of a copy with empty boxes keeps them', () async {
    final id = await newCollection();
    final stale = (await store.byId(id))!; // the words table's copy, no boxes
    expect(stale.boxes, isEmpty);

    expect(
        await store.update(id, (c) => c.boxes = [box('r1', 'walk', 2), box('r2', 'run', 1)]),
        isTrue);
    expect([for (final b in (await store.byId(id))!.boxes) b.box], [2, 1]);

    stale.words.first.translation = 'ходити';
    await store.put(stale);
    final read = (await store.byId(id))!;
    expect(read.words.first.translation, 'ходити');
    expect([for (final b in read.boxes) '${b.rowId}:${b.box}'], ['r1:2', 'r2:1']);
  });

  test('put() of a copy with older boxes never rolls them back', () async {
    final id = await newCollection();
    await store.update(id, (c) => c.boxes = [box('r1', 'walk', 2)]);
    final stale = (await store.byId(id))!; // holds box 2
    await store.update(id, (c) => c.boxes = [box('r1', 'walk', 3, lastUpDay: '2026-10-23')]);

    stale.boxes.first.box = 1; // even a changed stale copy is ignored
    await store.put(stale);
    final b = (await store.byId(id))!.boxes.single;
    expect(b.box, 3);
    expect(b.lastUpDay, '2026-10-23');
  });

  test('binning then restoring a collection keeps its boxes', () async {
    final id = await newCollection();
    await newCollection(); // the current one may not be binned; keep another
    await store.setCurrentCollectionId('somewhere-else');
    await store.update(id, (c) => c.boxes = [box('r1', 'walk', 4), box('r2', 'run', 5)]);

    expect((await store.bin(id)).result, BinResult.done);
    expect((await store.byId(id))!.boxes, hasLength(2));
    expect((await store.restore(id)).result, BinResult.done);
    final read = (await store.byId(id))!;
    expect(read.binnedAt, isNull);
    expect([for (final b in read.boxes) '${b.rowId}:${b.box}'], ['r1:4', 'r2:5']);
  });

  test('lastCheckSide round-trips JSON and copy; old JSON reads as empty (learn-welcome AC-07)', () {
    final a = box('r1', 'walk', 2)..lastCheckSide = 'uk';
    expect(a.copy().lastCheckSide, 'uk');
    final c = WordCollection.create()..boxes = [a];
    expect(WordCollection.fromJson(c.toJson()).boxes.single.lastCheckSide, 'uk');
    final json = a.toJson()..remove('lastCheckSide');
    expect(WordBox.fromJson(json).lastCheckSide, '');
  });

  test('put() keeps the stored lastCheckSide; update() changes it', () async {
    final id = await newCollection();
    await store.update(id, (c) => c.boxes = [box('r1', 'walk', 2)..lastCheckSide = 'uk']);
    final stale = (await store.byId(id))!;
    stale.boxes.first.lastCheckSide = 'en';
    await store.put(stale);
    expect((await store.byId(id))!.boxes.single.lastCheckSide, 'uk');

    await store.update(id, (c) => c.boxes = [box('r1', 'walk', 2)..lastCheckSide = 'en']);
    expect((await store.byId(id))!.boxes.single.lastCheckSide, 'en');
  });
}
