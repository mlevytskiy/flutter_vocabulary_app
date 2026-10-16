import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/tag_library_entry.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

import 'seed_collections.dart';

/// collection-tags T5 (ADR-0004, ADR-0009, sad §6 Flows 1, 2, 3, 5, 7):
/// description and typed tags are written only by the store's own
/// transactions, never undone by a stale put() or update(), and every
/// explicit add touches the tag library in the same transaction.
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
    dir = Directory.systemTemp.createTempSync('collection_tags_store_test');
    store = await CollectionStore.open(directory: dir.path);
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final old = DateTime(2026, 10, 1, 9);
  final detailsTime = DateTime(2026, 10, 10, 12);

  SessionSource photo(String id) => SessionSource()
    ..id = id
    ..fileName = '$id.jpg';

  /// A stored collection last edited at [old], with one word and the photo
  /// sources [sourceIds].
  Future<WordCollection> seeded({List<String> sourceIds = const []}) async {
    final c = WordCollection.create()
      ..updatedAt = old
      ..lastLocalModifiedAt = old
      ..name = 'Kitchen'
      ..words = [WordPair(word: 'apple', translation: 'яблуко')]
      ..sources = [for (final id in sourceIds) photo(id)];
    await seedCollection(store, c);
    return (await store.byId(c.collectionId))!;
  }

  Future<List<TagLibraryEntry>> library() =>
      Isar.getInstance('vocab')!.tagLibraryEntrys.where().findAll();

  Future<TagLibraryEntry?> entry(TagKind kind, String text) =>
      Isar.getInstance('vocab')!
          .tagLibraryEntrys
          .getByKindKey(kind, text.trim().toLowerCase());

  void expectDetailsKept(WordCollection? c) {
    expect(c, isNotNull);
    expect(c!.description, 'From the cooking podcast');
    expect(c.originTags, ['Podcast']);
    expect(c.topicTags, ['Food', 'Restaurants']);
    expect(c.updatedAt, detailsTime);
    expect(c.lastLocalModifiedAt, detailsTime);
  }

  group('stale writers after setDetails (AC-18, QG-1)', () {
    late WordCollection stale;
    late String id;

    setUp(() async {
      stale = await seeded(sourceIds: ['p1']);
      id = stale.collectionId;
      final stored = await store.setDetails(id,
          description: 'From the cooking podcast',
          origin: ['Podcast'],
          topic: ['Food', 'Restaurants'],
          now: detailsTime);
      expectDetailsKept(stored);
      // The stale copy still holds the old (empty) details and old times.
      expect(stale.description, isNull);
      expect(stale.topicTags, isEmpty);
    });

    test('a plain put of the old copy (autosave shape)', () async {
      stale.words = [
        ...stale.words,
        WordPair(word: 'pear', translation: 'груша')
      ];
      await store.put(stale);
      final after = await store.byId(id);
      expectDetailsKept(after);
      expect(after!.words.map((w) => w.word), ['apple', 'pear']);
    });

    test('a put that carries other details in the copy changes nothing',
        () async {
      stale
        ..description = 'stale'
        ..originTags = ['Book']
        ..topicTags = ['Old'];
      await store.put(stale);
      expectDetailsKept(await store.byId(id));
    });

    test('markShared shape: put of the copy with only the share fields set',
        () async {
      stale
        ..isShared = true
        ..publishedId = 'pub-1'
        ..editToken = 'tok';
      await store.put(stale);
      final after = await store.byId(id);
      expectDetailsKept(after);
      expect(after!.publishedId, 'pub-1');
    });

    test('updateDialogues / markDialoguesPublished / setScenePicture shape',
        () async {
      stale.dialogues = [FilmDialogue()..id = 'd1'];
      await store.put(stale);
      final after = await store.byId(id);
      expectDetailsKept(after);
      expect(after!.dialogues.single.id, 'd1');
    });

    test('History row republish shape: byId copy, then put', () async {
      final copy = (await store.byId(id))!..publishedId = 'pub-2';
      await store.put(copy);
      expectDetailsKept(await store.byId(id));
    });

    test('update(): dialogue delivery (dialogue_push)', () async {
      expect(
          await store.update(
              id, (s) => s.dialogues = [FilmDialogue()..id = 'd2']),
          isTrue);
      expectDetailsKept(await store.byId(id));
    });

    test('update(): story run and word grouping write groups', () async {
      await store.update(id, (s) {
        s.groups = [WordGroup()..id = 'g1'];
        s.selectedGroupId = 'g1';
      });
      final after = await store.byId(id);
      expectDetailsKept(after);
      expect(after!.groups.single.id, 'g1');
    });

    test('update(): learn appendResult', () async {
      expect(
          await store.appendResult(
              id,
              WordResult()
                ..rowId = stale.words.single.rowId
                ..at = DateTime(2026, 10, 11)),
          isTrue);
      final after = await store.byId(id);
      expectDetailsKept(after);
      expect(after!.results, hasLength(1));
    });

    test('update(): late lookup changes one row', () async {
      await store.update(id, (s) => s.words.first.translation = 'яблучко');
      final after = await store.byId(id);
      expectDetailsKept(after);
      expect(after!.words.first.translation, 'яблучко');
    });

    test('update(): a change that copies a stale copy over is undone',
        () async {
      await store.update(id, (s) {
        s
          ..description = stale.description
          ..originTags = stale.originTags
          ..topicTags = stale.topicTags;
      });
      expectDetailsKept(await store.byId(id));
    });
  });

  group('stale writers after saveSourceNote copy-up', () {
    late WordCollection stale;
    late String id;

    setUp(() async {
      stale = await seeded(sourceIds: ['p1', 'p2']);
      id = stale.collectionId;
      await store.setDetails(id,
          description: 'From the cooking podcast',
          origin: ['Podcast'],
          topic: ['Food'],
          now: DateTime(2026, 10, 5));
      final refused = await store.saveSourceNote(id, 'p1',
          title: 'Page 12', topic: ['Restaurants'], now: detailsTime);
      expect(refused, isEmpty);
    });

    test('the copy-up moved both times and added the tag', () async {
      expectDetailsKept(await store.byId(id));
    });

    test('a plain put of the old copy keeps the copied tag and the times',
        () async {
      stale.isShared = true;
      await store.put(stale);
      expectDetailsKept(await store.byId(id));
    });

    test('update() of a stale shape keeps them too', () async {
      await store.update(id, (s) => s.dialogues = [FilmDialogue()..id = 'd']);
      expectDetailsKept(await store.byId(id));
    });

    test('the source note is stored at once, so an adopted copy keeps it',
        () async {
      final adopted = (await store.byId(id))!;
      final source = adopted.sources.firstWhere((s) => s.id == 'p1');
      expect(source.title, 'Page 12');
      expect(source.topicTags, ['Restaurants']);
      // A later autosave of the adopted copy.
      adopted.words = [...adopted.words, WordPair(word: 'b', translation: 'б')];
      await store.put(adopted);
      final after = (await store.byId(id))!;
      expect(after.sources.firstWhere((s) => s.id == 'p1').topicTags,
          ['Restaurants']);
    });
  });

  group('setDetails (AC-06, AC-28)', () {
    test('saving without a change moves nothing and writes nothing', () async {
      final c = await seeded();
      final stored = await store.setDetails(c.collectionId,
          name: 'Kitchen', origin: [], topic: [], now: detailsTime);
      expect(stored!.updatedAt, old);
      expect(stored.lastLocalModifiedAt, old);
    });

    test('a change to the name alone moves both times', () async {
      final c = await seeded();
      final stored = await store.setDetails(c.collectionId,
          name: 'Kitchen talk', now: detailsTime);
      expect(stored!.name, 'Kitchen talk');
      expect(stored.updatedAt, detailsTime);
      expect(stored.lastLocalModifiedAt, detailsTime);
    });

    test('an invalid name writes nothing and answers null', () async {
      final c = await seeded();
      expect(
          await store.setDetails(c.collectionId,
              name: '  ', description: 'x', now: detailsTime),
          isNull);
      final after = (await store.byId(c.collectionId))!;
      expect(after.name, 'Kitchen');
      expect(after.description, isNull);
      expect(after.updatedAt, old);
    });

    test('an erased collection answers null', () async {
      expect(await store.setDetails('gone', description: 'x'), isNull);
    });

    test('a blank description is stored as null', () async {
      final c = await seeded();
      await store.setDetails(c.collectionId, description: 'Text');
      final stored = await store.setDetails(c.collectionId, description: '   ');
      expect(stored!.description, isNull);
    });

    test('a description sets keep, and it is never cleared', () async {
      final c = await store.create();
      expect(c.keep, isFalse);
      var stored = await store.setDetails(c.collectionId, description: 'Notes');
      expect(stored!.keep, isTrue);
      stored = await store.setDetails(c.collectionId, description: '');
      expect(stored!.keep, isTrue);
    });

    test('a typed tag sets keep', () async {
      final c = await store.create();
      final stored = await store.setDetails(c.collectionId, origin: ['Book']);
      expect(stored!.keep, isTrue);
    });

    test('a blank description alone does not set keep', () async {
      final c = await store.create();
      final stored = await store.setDetails(c.collectionId, description: ' ');
      expect(stored!.keep, isFalse);
    });

    test('omitted fields stay as they are', () async {
      final c = await seeded();
      await store.setDetails(c.collectionId,
          description: 'D', origin: ['Book'], topic: ['Food']);
      final stored =
          await store.setDetails(c.collectionId, topic: ['Food', 'Idioms']);
      expect(stored!.description, 'D');
      expect(stored.originTags, ['Book']);
      expect(stored.topicTags, ['Food', 'Idioms']);
    });
  });

  group('create with details (Flow 3, AC-01, AC-27)', () {
    test('writes name, description and tags, keeps it, touches the library',
        () async {
      final c = await store.create(
          folderId: null,
          name: 'Dark S1',
          description: 'German series',
          origin: ['Netflix'],
          topic: ['Mystery']);
      final stored = (await store.byId(c.collectionId))!;
      expect(stored.name, 'Dark S1');
      expect(stored.description, 'German series');
      expect(stored.originTags, ['Netflix']);
      expect(stored.topicTags, ['Mystery']);
      expect(stored.keep, isTrue);
      expect((await entry(TagKind.origin, 'netflix'))!.text, 'Netflix');
      expect((await entry(TagKind.topic, 'Mystery'))!.lastUsedAt, isNotNull);
    });

    test('without details it behaves as before', () async {
      final c = await store.create();
      final stored = (await store.byId(c.collectionId))!;
      expect(stored.keep, isFalse);
      expect(stored.description, isNull);
      expect(stored.originTags, isEmpty);
      expect(await library(), isEmpty);
    });
  });

  group('tag library (AC-09, AC-12, AC-30)', () {
    test('the first spelling wins and one entry is kept', () async {
      final a = await seeded();
      final b = await seeded();
      await store.setDetails(a.collectionId, topic: ['Food']);
      await store.setDetails(b.collectionId, topic: ['food']);
      final topics =
          (await library()).where((e) => e.kind == TagKind.topic).toList();
      expect(topics.map((e) => e.text), ['Food']);
    });

    test('the same text in both kinds is two entries (AC-11)', () async {
      final a = await seeded();
      await store
          .setDetails(a.collectionId, origin: ['Travel'], topic: ['Travel']);
      expect(await library(), hasLength(2));
    });

    test('only newly added tags are touched', () async {
      final a = await seeded();
      await store.setDetails(a.collectionId,
          topic: ['Food'], now: DateTime(2026, 10, 2));
      await store.setDetails(a.collectionId,
          topic: ['food', 'Idioms'], now: DateTime(2026, 10, 3));
      expect((await entry(TagKind.topic, 'Food'))!.lastUsedAt,
          DateTime(2026, 10, 2));
      expect((await entry(TagKind.topic, 'Idioms'))!.lastUsedAt,
          DateTime(2026, 10, 3));
    });

    test('forget hides a tag, collections keep it, an explicit add un-forgets',
        () async {
      final a = await seeded();
      await store.setDetails(a.collectionId, topic: ['Fodo']);
      await store.forgetTag(TagKind.topic, 'fodo');
      expect((await entry(TagKind.topic, 'Fodo'))!.forgotten, isTrue);
      expect((await store.byId(a.collectionId))!.topicTags, ['Fodo']);

      final b = await seeded();
      await store.setDetails(b.collectionId, topic: ['FODO']);
      final e = (await entry(TagKind.topic, 'Fodo'))!;
      expect(e.forgotten, isFalse);
      expect(e.text, 'Fodo');
    });

    test('forgetting an unknown tag does nothing', () async {
      await store.forgetTag(TagKind.origin, 'nothing');
      expect(await library(), isEmpty);
    });

    test('addCollectionTags un-forgets too', () async {
      final a = await seeded();
      await store.setDetails(a.collectionId, topic: ['Fodo']);
      await store.forgetTag(TagKind.topic, 'Fodo');
      await store.setDetails(a.collectionId, topic: []);
      await store.addCollectionTags(a.collectionId, TagKind.topic, ['fodo']);
      expect((await entry(TagKind.topic, 'Fodo'))!.forgotten, isFalse);
    });

    test('watchLibrary emits on listen and after a write', () async {
      final a = await seeded();
      final events = <List<String>>[];
      final sub = store
          .watchLibrary()
          .listen((l) => events.add([for (final e in l) e.text]));
      await pumpEventQueue();
      await store.setDetails(a.collectionId, origin: ['Book']);
      await pumpEventQueue();
      await sub.cancel();
      expect(events.first, isEmpty);
      expect(events.last, ['Book']);
    });
  });

  group('saveSourceNote copy-up (AC-15, AC-16, AC-29, AC-33)', () {
    late String id;

    setUp(() async {
      id = (await seeded(sourceIds: ['p1', 'p2', 'p3'])).collectionId;
    });

    Future<WordCollection> stored() async => (await store.byId(id))!;
    SessionSource src(WordCollection c, String sid) =>
        c.sources.firstWhere((s) => s.id == sid);

    test('writes the note fields of the source', () async {
      await store.saveSourceNote(id, 'p1',
          title: 'Page 12',
          description: 'menu',
          links: ['https://a.b'],
          origin: ['Book'],
          topic: ['Restaurants']);
      final s = src(await stored(), 'p1');
      expect(s.title, 'Page 12');
      expect(s.description, 'menu');
      expect(s.links, ['https://a.b']);
      expect(s.originTags, ['Book']);
      expect(s.topicTags, ['Restaurants']);
      final c = await stored();
      expect(c.originTags, ['Book']);
      expect(c.topicTags, ['Restaurants']);
      expect(
          (await entry(TagKind.topic, 'restaurants'))!.lastUsedAt, isNotNull);
    });

    test('a second source does not add it twice, ignoring case', () async {
      await store.saveSourceNote(id, 'p1', topic: ['Restaurants']);
      await store.saveSourceNote(id, 'p2', topic: ['restaurants']);
      expect((await stored()).topicTags, ['Restaurants']);
      expect(src(await stored(), 'p2').topicTags, ['restaurants']);
    });

    test('a full kind refuses the copy, named once, the source keeps it',
        () async {
      await store.setDetails(id,
          topic: [for (var i = 0; i < 10; i++) 'T$i'], now: detailsTime);
      final refused = await store.saveSourceNote(id, 'p1',
          origin: ['Book'],
          topic: ['Restaurants', 'Cafes'],
          now: DateTime(2026, 10, 12));
      expect(refused, {TagKind.topic});
      final c = await stored();
      expect(c.topicTags, hasLength(10));
      expect(c.originTags, ['Book']);
      expect(src(c, 'p1').topicTags, ['Restaurants', 'Cafes']);
      // Refused tags still touch the library.
      expect(await entry(TagKind.topic, 'Cafes'), isNotNull);
    });

    test('re-saving unchanged tags copies nothing', () async {
      await store.saveSourceNote(id, 'p1',
          topic: ['Restaurants'], now: DateTime(2026, 10, 2));
      await store.setDetails(id, topic: [], now: DateTime(2026, 10, 3));
      await store.saveSourceNote(id, 'p1',
          title: 'renamed', topic: ['Restaurants'], now: DateTime(2026, 10, 4));
      expect((await stored()).topicTags, isEmpty);
      expect((await entry(TagKind.topic, 'Restaurants'))!.lastUsedAt,
          DateTime(2026, 10, 2));
    });

    test('a re-add after removal copies again', () async {
      await store.saveSourceNote(id, 'p1', topic: ['Restaurants']);
      await store.setDetails(id, topic: []);
      await store.saveSourceNote(id, 'p2', topic: ['Restaurants']);
      expect((await stored()).topicTags, ['Restaurants']);
    });

    test('removing from the source touches only the source', () async {
      await store.saveSourceNote(id, 'p1', topic: ['Restaurants']);
      await store.saveSourceNote(id, 'p1', topic: []);
      final c = await stored();
      expect(src(c, 'p1').topicTags, isEmpty);
      expect(c.topicTags, ['Restaurants']);
    });

    test('a saved note moves both times; an unchanged one moves nothing',
        () async {
      await store.saveSourceNote(id, 'p1', title: 'A', now: detailsTime);
      var c = await stored();
      expect(c.updatedAt, detailsTime);
      expect(c.lastLocalModifiedAt, detailsTime);
      await store.saveSourceNote(id, 'p1',
          title: 'A', now: DateTime(2026, 10, 20));
      c = await stored();
      expect(c.updatedAt, detailsTime);
    });

    test('an unknown source or collection writes nothing', () async {
      expect(await store.saveSourceNote(id, 'nope', topic: ['X']), isEmpty);
      expect(await store.saveSourceNote('gone', 'p1', topic: ['X']), isEmpty);
      expect((await stored()).topicTags, isEmpty);
      expect(await library(), isEmpty);
    });
  });

  group('addCollectionTags', () {
    test('adds missing tags, skips case duplicates, refuses past 10', () async {
      final c = await seeded();
      await store.setDetails(c.collectionId,
          origin: [for (var i = 0; i < 9; i++) 'O$i']);
      final refused = await store.addCollectionTags(
          c.collectionId, TagKind.origin, ['o1', 'Film', 'Book']);
      expect(refused, {TagKind.origin});
      final stored = (await store.byId(c.collectionId))!;
      expect(stored.originTags, hasLength(10));
      expect(stored.originTags.last, 'Film');
    });

    test('moves the times only when something was added', () async {
      final c = await seeded();
      await store.setDetails(c.collectionId, topic: ['Food'], now: detailsTime);
      await store.addCollectionTags(c.collectionId, TagKind.topic, ['food'],
          now: DateTime(2026, 10, 20));
      expect((await store.byId(c.collectionId))!.updatedAt, detailsTime);
    });
  });
}
