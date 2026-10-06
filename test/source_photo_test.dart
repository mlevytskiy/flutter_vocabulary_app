import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// good-looking-web T17: the app keeps each source photo and links the rows
/// recognised from it (spec AC-25, AC-26).
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

  SessionSource photo(String id, {String? fileName, DateTime? takenAt}) =>
      SessionSource()
        ..id = id
        ..fileName = fileName ?? '$id.jpg'
        ..takenAt = takenAt ?? DateTime.utc(2026, 9, 28, 10, 30);

  group('SessionSource kind, name, url', () {
    // AC-13b, AC-15: sources of both kinds live in one list.
    test('JSON without kind reads as a photo; round trip keeps a set', () {
      final legacy = SessionSource.fromJson({
        'id': 'a1',
        'fileName': 'a1.jpg',
        'takenAt': '2026-09-28T10:00:00.000Z',
      });
      expect(legacy.kind, SourceKind.photo);
      expect(legacy.name, isNull);
      expect(legacy.url, isNull);
      expect(legacy.toJson()['kind'], 'photo');

      final set = SessionSource()
        ..id = 's1'
        ..kind = SourceKind.set
        ..name = 'Biology'
        ..url = 'https://quizlet.com/123/biology/';
      final back = SessionSource.fromJson(set.toJson());
      expect(back.kind, SourceKind.set);
      expect(back.name, 'Biology');
      expect(back.url, 'https://quizlet.com/123/biology/');
      final c = set.copy();
      expect([c.kind, c.name, c.url],
          [SourceKind.set, 'Biology', 'https://quizlet.com/123/biology/']);
      expect(SourceKind.values.first, SourceKind.photo);
    });

    test('Isar keeps kind, name and url; photos read back as photos',
        () async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('session_source_kind');
      final store = await SessionStore.open(directory: dir.path);
      try {
        final session = Session.create()
          ..sources = [
            photo('p1'),
            SessionSource()
              ..id = 's1'
              ..kind = SourceKind.set
              ..name = 'Biology'
              ..url = 'https://quizlet.com/123/biology/',
          ];
        await store.put(session);
        final back = (await store.byId(session.sessionId))!;
        expect(back.sources.map((s) => s.kind).toList(),
            [SourceKind.photo, SourceKind.set]);
        expect(back.sources[0].name, isNull);
        expect(back.sources[1].name, 'Biology');
        expect(back.sources[1].url, 'https://quizlet.com/123/biology/');
      } finally {
        await store.close();
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('JSON', () {
    // AC-26
    test('a session saved before this change loads with no sources and null '
        'sourceIds', () {
      final legacy = Session.fromJson({
        'sessionId': 'old-1',
        'updatedAt': '2026-05-01T10:00:00.000',
        'lastLocalModifiedAt': '2026-05-01T10:00:00.000',
        'isShared': true,
        'words': [
          {
            'word': 'direct',
            'translation': 'прямий',
            'hasTranslationOptions': false,
            'translationOptionsJson': null,
            'wordMarkedFilled': true,
            'translationMarkedFilled': true,
            'definition': 'straight',
            'definitionOptionsJson': null,
            'definitionMarkedFilled': false,
          },
        ],
      });
      expect(legacy.sources, isEmpty);
      expect(legacy.publishedId, isNull);
      expect(legacy.editToken, isNull);
      expect(legacy.words.single.sourceId, isNull);
      expect(legacy.words.single.translation, 'прямий');
      expect(legacy.isShared, isTrue);
    });

    test('round trip keeps sources, sourceId, publishedId, editToken', () {
      final session = Session.create()
        ..sources = [
          photo('a1b2', takenAt: DateTime.utc(2026, 9, 28, 10)),
          photo('c3d4', takenAt: DateTime.utc(2026, 9, 28, 11)),
        ]
        ..publishedId = 'pub-42'
        ..editToken = 'tok-secret'
        ..words = [
          WordPair(word: 'apple', translation: 'яблуко', sourceId: 'a1b2'),
          WordPair(word: 'pear', translation: 'груша'),
          WordPair(word: 'plum', translation: 'слива', sourceId: 'c3d4'),
        ];

      final back = Session.fromJson(session.toJson());

      expect(back.sources.map((s) => s.id).toList(), ['a1b2', 'c3d4']);
      expect(back.sources.map((s) => s.fileName).toList(),
          ['a1b2.jpg', 'c3d4.jpg']);
      expect(back.sources.map((s) => s.takenAt).toList(),
          [DateTime.utc(2026, 9, 28, 10), DateTime.utc(2026, 9, 28, 11)]);
      expect(back.publishedId, 'pub-42');
      expect(back.editToken, 'tok-secret');
      expect(back.words.map((w) => w.sourceId).toList(),
          ['a1b2', null, 'c3d4']);
    });

    test('copy() keeps sourceId', () {
      expect(WordPair(word: 'x', sourceId: 'p1').copy().sourceId, 'p1');
      expect(WordPair(word: 'x').copy().sourceId, isNull);
    });
  });

  test('a photo word is tagged with its photo, only when one was kept', () {
    final w = VocabWord(word: 'tenacious', translation: 'наполегливий');
    expect(wordPairFromPhoto(w, sourceId: 'p1').sourceId, 'p1');
    expect(wordPairFromPhoto(w).sourceId, isNull);
  });

  group('SessionStore', () {
    late Directory dir;
    late SessionStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('source_photo_session_test');
      store = await SessionStore.open(directory: dir.path);
    });

    tearDown(() async {
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('keeps sources, sourceIds, publishedId and editToken', () async {
      final session = Session.create()
        ..sources = [photo('a1b2')]
        ..publishedId = 'pub-42'
        ..editToken = 'tok'
        ..words = [
          WordPair(word: 'apple', translation: 'яблуко', sourceId: 'a1b2'),
          WordPair(word: 'typed', translation: 'набраний'),
        ];

      await store.put(session);
      final back = (await store.byId(session.sessionId))!;

      expect(back.sources.single.id, 'a1b2');
      expect(back.sources.single.fileName, 'a1b2.jpg');
      // Isar hands DateTimes back in local time; the instant is what counts.
      expect(
          back.sources.single.takenAt
              .isAtSameMomentAs(DateTime.utc(2026, 9, 28, 10, 30)),
          isTrue);
      expect(back.publishedId, 'pub-42');
      expect(back.editToken, 'tok');
      expect(back.words.map((w) => w.sourceId).toList(), ['a1b2', null]);
    });

    // AC-26
    test('a session without photos stores and loads with none', () async {
      final session = Session.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await store.put(session);
      final back = (await store.byId(session.sessionId))!;
      expect(back.sources, isEmpty);
      expect(back.publishedId, isNull);
      expect(back.editToken, isNull);
      expect(back.words.single.sourceId, isNull);
    });
  });

  group('SourcePhotoStore', () {
    late Directory dir;
    late SourcePhotoStore photos;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('source_photo_store_test');
      photos = SourcePhotoStore(directory: dir.path);
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('keep writes the bytes under a fresh UUID and reads them back',
        () async {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
      final takenAt = DateTime(2026, 9, 28, 12);

      final kept = await photos.keep(bytes, takenAt: takenAt);

      expect(kept, isNotNull);
      expect(
          kept!.id,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(kept.fileName, '${kept.id}.jpg');
      expect(kept.takenAt, takenAt);
      expect(await photos.read(kept), bytes);
      expect((await photos.fileFor(kept)).existsSync(), isTrue);

      final other = await photos.keep(bytes, takenAt: takenAt);
      expect(other!.id, isNot(kept.id));
    });

    test('delete removes the file; reading a missing photo answers null',
        () async {
      final kept = (await photos.keep(Uint8List.fromList([1, 2, 3]),
          takenAt: DateTime(2026)))!;

      await photos.delete(kept);

      expect((await photos.fileFor(kept)).existsSync(), isFalse);
      expect(await photos.read(kept), isNull);
      // A second delete of the same photo is harmless.
      await photos.delete(kept);
    });
  });

  group('WordInputNotifier', () {
    late Directory dir;
    late SessionStore store;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('source_photo_notifier_test');
      store = await SessionStore.open(directory: dir.path);
      container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    Session session() => container.read(wordInputNotifierProvider).value!;

    // AC-25
    test('a photo and its rows are saved; a typed row has no photo', () async {
      await container.read(wordInputNotifierProvider.future);
      final notifier = container.read(wordInputNotifierProvider.notifier);
      notifier.setPairs([WordPair(word: 'typed', translation: 'набраний')]);

      notifier.addSource(photo('p1'));
      notifier.addAll([
        WordPair(word: 'apple', translation: 'яблуко', sourceId: 'p1'),
      ]);
      notifier.addSource(photo('p2'));
      notifier.addAll([
        WordPair(word: 'plum', translation: 'слива', sourceId: 'p2'),
      ]);
      await notifier.flush();

      final back = (await store.byId(session().sessionId))!;
      expect(back.sources.map((s) => s.id).toList(), ['p1', 'p2']);
      expect(back.words.map((w) => w.sourceId).toList(), [null, 'p1', 'p2']);
    });

    test('editing a row keeps its photo; clearing it drops the photo',
        () async {
      await container.read(wordInputNotifierProvider.future);
      final notifier = container.read(wordInputNotifierProvider.notifier);
      notifier.setPairs([WordPair(word: 'apple', sourceId: 'p1'), WordPair()]);

      notifier.updateAt(0, translation: 'яблуко');
      expect(session().words[0].sourceId, 'p1');

      notifier.updateAt(1, word: 'plum', sourceId: 'p2');
      expect(session().words[1].sourceId, 'p2');

      notifier.updateAt(0, word: '', translation: '', clearSourceId: true);
      expect(session().words[0].sourceId, isNull);
    });

    test('a stored session with sources can take another photo', () async {
      final prev = Session.create()
        ..sources = [photo('p1')]
        ..words = [WordPair(word: 'apple', sourceId: 'p1')];
      await store.put(prev);
      await store.setCurrentSessionId(prev.sessionId);

      await container.read(wordInputNotifierProvider.future);
      container.read(wordInputNotifierProvider.notifier).addSource(photo('p2'));

      expect(session().sources.map((s) => s.id).toList(), ['p1', 'p2']);
    });
  });
}
