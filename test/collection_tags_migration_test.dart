import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/effective_tags.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/tag_library_entry.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

/// collection-tags T6 (ADR-0003, data-model §Migration, sad §6 Flow 9):
/// the one-time move of untyped tags into origin and topic tags on store
/// open, and the legacy-as-topic fallback (sad §8).
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
  CollectionStore? store;
  final logs = <String>[];
  final savedDebugPrint = debugPrint;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_tags_migration');
    // The store reuses an open `vocab` instance, so records seeded here are
    // what it finds on open, exactly like a database from an older build.
    isar = await Isar.open([
      WordCollectionSchema,
      StoryRunSchema,
      CollectionFolderSchema,
      TagLibraryEntrySchema,
    ], directory: dir.path, name: 'vocab');
    logs.clear();
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  });

  tearDown(() async {
    debugPrint = savedDebugPrint;
    final s = store;
    store = null;
    if (s != null) {
      await s.close();
    } else if (isar.isOpen) {
      await isar.close();
    }
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final edited = DateTime(2026, 9, 9, 9);

  String idAt(DateTime t) =>
      '${t.microsecondsSinceEpoch.toRadixString(36)}-abc';

  SessionSource source(String id, List<String> tags) => SessionSource()
    ..id = id
    ..fileName = '$id.jpg'
    ..tags = [...tags];

  /// A record as the build before collection-tags wrote it: untyped tags.
  WordCollection legacy(DateTime made, List<String> tags,
          {List<SessionSource> sources = const []}) =>
      WordCollection()
        ..collectionId = idAt(made)
        ..name = 'C ${made.month}'
        ..updatedAt = edited
        ..lastLocalModifiedAt = edited
        ..tags = [...tags]
        ..sources = [...sources];

  Future<void> seed(List<WordCollection> cs) =>
      isar.writeTxn(() => isar.wordCollections.putAll(cs));

  Future<void> open() async {
    store = await CollectionStore.open(directory: dir.path);
    isar = Isar.getInstance('vocab')!;
  }

  Future<void> reopen() async {
    await store!.close();
    store = null;
    await open();
  }

  Future<WordCollection> read(WordCollection c) async =>
      (await isar.wordCollections
          .filter()
          .collectionIdEqualTo(c.collectionId)
          .findFirst())!;

  Future<List<TagLibraryEntry>> library() =>
      isar.tagLibraryEntrys.where().findAll();

  Future<TagLibraryEntry?> entry(TagKind kind, String text) =>
      isar.tagLibraryEntrys.getByKindKey(kind, text.toLowerCase());

  final topics14 = [for (var i = 1; i <= 14; i++) 'topic$i'];
  final long40 = 'x' * 40;

  /// data-model "Test fixtures": `legacyTagsFixture()`.
  ({
    WordCollection a,
    WordCollection b,
    WordCollection travel,
    WordCollection x,
    WordCollection y,
    WordCollection many,
  }) legacyTagsFixture() => (
        a: legacy(DateTime(2026, 2, 1), [
          'Book',
          'food',
          'Friends'
        ], sources: [
          source('s1', ['Podcast'])
        ]),
        b: legacy(DateTime(2026, 3, 1), ['Food', 'food', long40, ...topics14]),
        travel: legacy(DateTime(2026, 4, 1), ['Travel', 'travel']),
        x: legacy(DateTime(2026, 1, 1), ['food']),
        y: legacy(DateTime(2026, 5, 1), ['Food']),
        many: legacy(DateTime(2026, 6, 1), [], sources: [
          source('s2', topics14),
          source('s3', ['Book'])
        ]),
      );

  test(
      'AC-17: presets become origin tags, source tags copy up, library has all',
      () async {
    final f = legacyTagsFixture();
    await seed([f.a]);
    await open();

    final a = await read(f.a);
    expect(a.originTags, ['Book', 'Podcast']);
    expect(a.topicTags, ['food', 'Friends']);
    expect(a.tags, isEmpty);
    expect(a.sources.single.originTags, ['Podcast']);
    expect(a.sources.single.topicTags, isEmpty);
    expect(a.sources.single.tags, isEmpty);
    expect(a.keep, isTrue);
    final lib = {for (final e in await library()) (e.kind, e.text)};
    expect(lib, {
      (TagKind.origin, 'Book'),
      (TagKind.origin, 'Podcast'),
      (TagKind.topic, 'food'),
      (TagKind.topic, 'Friends'),
    });
  });

  test('AC-17b: case duplicates merge into the first, long and many kept',
      () async {
    final f = legacyTagsFixture();
    await seed([f.b]);
    await open();

    final b = await read(f.b);
    expect(b.originTags, isEmpty);
    expect(b.topicTags, ['Food', long40, ...topics14]);
    expect(b.topicTags, hasLength(16));
  });

  test('AC-31: an old "Travel" becomes an origin tag', () async {
    final f = legacyTagsFixture();
    await seed([f.travel]);
    await open();

    final t = await read(f.travel);
    expect(t.originTags, ['Travel']);
    expect(t.topicTags, isEmpty);
    expect((await entry(TagKind.origin, 'travel'))!.text, 'Travel');
  });

  test(
      'AC-32: each collection keeps its spelling, the library the oldest one, '
      'never dated', () async {
    final f = legacyTagsFixture();
    // Seeded newest first so the Isar id order is not the answer.
    await seed([f.y, f.x]);
    await open();

    expect((await read(f.x)).topicTags, ['food']);
    expect((await read(f.y)).topicTags, ['Food']);
    final lib = await library();
    expect(lib, hasLength(1));
    expect(lib.single.text, 'food');
    expect(lib.single.lastUsedAt, isNull);
    expect(lib.single.forgotten, isFalse);
  });

  test('source tags are copied up to the collection past the 10 cap', () async {
    final f = legacyTagsFixture();
    await seed([f.many]);
    await open();

    final m = await read(f.many);
    expect(m.topicTags, topics14);
    expect(m.originTags, ['Book']);
    expect(m.sources[0].topicTags, topics14);
    expect(m.sources[1].originTags, ['Book']);
    expect(m.sources.every((s) => s.tags.isEmpty), isTrue);
  });

  test('typed tags already there are kept and not repeated', () async {
    final c = legacy(DateTime(2026, 2, 1), ['food', 'Book'])
      ..topicTags = ['Food']
      ..originTags = ['Film'];
    await seed([c]);
    await open();

    final r = await read(c);
    expect(r.originTags, ['Film', 'Book']);
    expect(r.topicTags, ['Food']);
  });

  test('times stay, legacy lists empty, a second open changes nothing',
      () async {
    final f = legacyTagsFixture();
    final all = [f.a, f.b, f.travel, f.x, f.y, f.many];
    await seed(all);
    await open();

    String snapshot(List<WordCollection> cs) =>
        jsonEncode([for (final c in cs) c.toJson()]);
    final first = [for (final c in all) await read(c)];
    for (final c in first) {
      expect(c.updatedAt, edited);
      expect(c.lastLocalModifiedAt, edited);
      expect(c.tags, isEmpty);
      expect(c.sources.every((s) => s.tags.isEmpty), isTrue);
    }
    final lib1 = [
      for (final e in await library()) '${e.kind}/${e.key}/${e.text}'
    ];
    expect(await library(),
        everyElement(predicate<TagLibraryEntry>((e) => e.lastUsedAt == null)));

    await reopen();

    final second = [for (final c in all) await read(c)];
    expect(snapshot(second), snapshot(first));
    expect([for (final e in await library()) '${e.kind}/${e.key}/${e.text}'],
        lib1);
    expect(logs.where((l) => l.contains('tag migration failed')), isEmpty);
  });

  test('a forgotten library tag stays forgotten and keeps its spelling',
      () async {
    await isar.writeTxn(() => isar.tagLibraryEntrys.put(TagLibraryEntry()
      ..kind = TagKind.topic
      ..key = 'food'
      ..text = 'FOOD'
      ..forgotten = true));
    final c = legacy(DateTime(2026, 2, 1), ['food']);
    await seed([c]);
    await open();

    final e = (await entry(TagKind.topic, 'food'))!;
    expect(e.forgotten, isTrue);
    expect(e.text, 'FOOD');
    expect(e.lastUsedAt, isNull);
    expect((await read(c)).topicTags, ['food']);
  });

  test('a collection without tags is not touched and keep stays', () async {
    final c = legacy(DateTime(2026, 2, 1), []);
    await seed([c]);
    final before = jsonEncode((await read(c)).toJson());
    await open();

    final r = await read(c);
    expect(jsonEncode(r.toJson()), before);
    expect(r.keep, isFalse);
  });

  test('spec §6: 500 collections migrate within 1 s', () async {
    final cs = [
      for (var i = 0; i < 500; i++)
        legacy(DateTime(2026, 1, 1).add(Duration(minutes: i)), [
          'Book',
          'tag${i % 50}',
          'Topic${i % 7}'
        ], sources: [
          source('s$i', ['Podcast', 'src${i % 30}'])
        ]),
    ];
    await seed(cs);

    final watch = Stopwatch()..start();
    await open();
    watch.stop();

    expect(watch.elapsedMilliseconds, lessThan(1000));
    final last = await read(cs.last);
    expect(last.originTags, ['Book', 'Podcast']);
    expect(last.topicTags, ['tag49', 'Topic2', 'src19']);
    expect(await isar.wordCollections.filter().tagsIsNotEmpty().count(), 0);
  });

  group('effectiveTags (sad §8 legacy fallback)', () {
    test('legacy tags read as topic tags while both typed lists are empty', () {
      final r = effectiveTags(origin: [], topic: [], legacy: ['Book', 'food']);
      expect(r.origin, isEmpty);
      expect(r.topic, ['Book', 'food']);
    });

    test('typed tags win as soon as either list has one', () {
      expect(effectiveTags(origin: ['Film'], topic: [], legacy: ['food']).topic,
          isEmpty);
      final r = effectiveTags(origin: [], topic: ['Food'], legacy: ['x']);
      expect(r.origin, isEmpty);
      expect(r.topic, ['Food']);
    });

    test('nothing anywhere is nothing', () {
      final r = effectiveTags(origin: [], topic: [], legacy: []);
      expect(r.origin, isEmpty);
      expect(r.topic, isEmpty);
    });

    test('a collection and a source read their own lists', () {
      final c = WordCollection()
        ..tags = ['food']
        ..sources = [
          source('s', ['Podcast'])..topicTags = ['Jazz']
        ];
      expect(effectiveTagsOf(c).topic, ['food']);
      expect(effectiveSourceTagsOf(c.sources.single).topic, ['Jazz']);
      expect(effectiveSourceTagsOf(c.sources.single).origin, isEmpty);
    });
  });
}
